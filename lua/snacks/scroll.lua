---@class snacks.scroll
local M = {}

---@alias snacks.scroll.View {topline:number, lnum:number}

---@class snacks.scroll.State
---@field buf number
---@field view snacks.scroll.View
---@field current snacks.scroll.View
---@field target snacks.scroll.View
---@field scrolloff number
---@field mousescroll number
---@field height number

---@class snacks.scroll.Config
---@field animate snacks.animate.Config
local defaults = {
  animate = {
    duration = { step = 10, total = 250 },
    easing = "linear",
  },
  -- what buffers to animate
  filter = function(buf)
    return vim.g.snacks_scroll ~= false and vim.b[buf].snacks_scroll ~= false
  end,
  debug = false,
}

M.enabled = false

local states = {} ---@type table<number, snacks.scroll.State>
local stats = { targets = 0, animating = 0, reset = 0, skipped = 0 }
local config = Snacks.config.get("scroll", defaults)
local debug_timer = assert((vim.uv or vim.loop).new_timer())

local function get_state(win)
  local buf = vim.api.nvim_win_get_buf(win)
  if not config.filter(buf) then
    return
  end
  local view = vim.api.nvim_win_call(win, vim.fn.winsaveview) ---@type vim.fn.winsaveview.ret
  view = { topline = view.topline, lnum = view.lnum } --[[@as snacks.scroll.View]]
  if not (states[win] and states[win].buf == buf) then
    ---@diagnostic disable-next-line: missing-fields
    states[win] = {
      animating = false,
      target = vim.deepcopy(view),
      current = vim.deepcopy(view),
      buf = buf,
    }
  end
  states[win].scrolloff = vim.wo[win].scrolloff
  states[win].mousescroll = tonumber(vim.o.mousescroll:match("ver:(%d+)")) or 1
  states[win].height = vim.api.nvim_win_get_height(win)
  states[win].view = view
  return states[win]
end

function M.enable()
  if M.enabled then
    return
  end
  M.enabled = true
  states = {}
  if config.debug then
    M.debug()
  end

  -- get initial state for all windows
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    get_state(win)
  end

  local group = vim.api.nvim_create_augroup("snacks_scroll", { clear = true })

  -- initialize state for buffers entering windows
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    callback = vim.schedule_wrap(function(ev)
      for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
        get_state(win)
      end
    end),
  })

  -- update current state on cursor move
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = group,
    callback = vim.schedule_wrap(function(ev)
      for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
        if states[win] then
          states[win].current.lnum = vim.api.nvim_win_get_cursor(win)[1]
        end
      end
    end),
  })

  -- listen to scroll events with topline changes
  vim.api.nvim_create_autocmd("WinScrolled", {
    group = group,
    callback = function()
      for win, changes in pairs(vim.v.event) do
        win = tonumber(win)
        if win and changes.topline ~= 0 then
          M.update(win)
        end
      end
    end,
  })
end

function M.disable()
  if not M.enabled then
    return
  end
  M.enabled = false
  states = {}
  vim.api.nvim_del_augroup_by_name("snacks_scroll")
end

--- Check if we need to animate the scroll
---@param win number
function M.update(win)
  local state = get_state(win)
  if not state then
    return
  end

  if math.abs(state.view.topline - state.current.topline) <= state.mousescroll then
    stats.skipped = stats.skipped + 1
    state.current = vim.deepcopy(state.view)
    return
  end

  local function update(changes)
    if not vim.api.nvim_win_is_valid(win) then
      return
    end

    state.current = changes and vim.tbl_extend("force", state.current, changes) or state.current

    -- adjust lnum for scrolloff when not at target topline
    if state.target.topline == state.current.topline then
      state.current.lnum = state.target.lnum
    else
      state.current.lnum = math.max(
        state.current.topline + state.scrolloff,
        math.min(state.current.lnum, state.current.topline + state.height - 1 - state.scrolloff)
      )
    end

    if changes then
      stats.animating = stats.animating + 1
    else
      stats.reset = stats.reset + 1
    end

    -- always restore view, since it might be a lnum change
    vim.api.nvim_win_call(win, function()
      vim.fn.winrestview(state.current)
    end)
  end

  stats.targets = stats.targets + 1
  state.target = vim.deepcopy(state.view)
  update() -- reset to current state

  -- animate topline/lnum to target
  for _, field in ipairs({ "topline", "lnum" }) do
    Snacks.animate.animate(
      state.current[field],
      state.target[field],
      function(value)
        update({ [field] = value })
      end,
      vim.tbl_extend("keep", {
        int = true,
        id = ("scroll_%s_%d"):format(field, win),
      }, config.animate)
    )
  end
end

function M.debug()
  if debug_timer:is_active() then
    debug_timer:stop()
    return
  end
  local last = {}
  local _states = {}
  debug_timer:start(50, 50, function()
    if not vim.deep_equal(stats, last) then
      last = vim.deepcopy(stats)
      Snacks.notify(vim.inspect(stats), { ft = "lua", id = "snacks_scroll_debug", title = "Snacks Scroll Debug Stats" })
    end
    for win, state in pairs(states) do
      if not vim.deep_equal(_states[win], state) then
        Snacks.notify(
          vim.inspect(state),
          { ft = "lua", id = "snacks_scroll_debug_" .. win, title = "Snacks Scroll Debug " .. win }
        )
      end
    end
    _states = vim.deepcopy(states)
  end)
end

return M
