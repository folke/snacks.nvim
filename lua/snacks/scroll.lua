---@class snacks.scroll
local M = {}

---@alias snacks.scroll.View {topline:number, lnum:number}

---@class snacks.scroll.State
---@field buf number
---@field animating? boolean
---@field view snacks.scroll.View
---@field current snacks.scroll.View
---@field target snacks.scroll.View

---@class snacks.scroll.Config
---@field animate snacks.animate.Config
local defaults = {
  animate = {
    duration = { step = 20, total = 250 },
    easing = "linear",
  },
  -- what buffers to animate
  filter = function(buf)
    return vim.g.snacks_scroll ~= false and vim.b[buf].snacks_scroll ~= false
  end,
  debug = false,
}

local states = {} ---@type table<number, snacks.scroll.State>
local stats = { targets = 0, animating = 0 }
local config = Snacks.config.get("scroll", defaults)
local debug_timer = assert((vim.uv or vim.loop).new_timer())

local function get_state(win)
  local buf = vim.api.nvim_win_get_buf(win)
  if not config.filter(buf) then
    return
  end
  local view = vim.api.nvim_win_call(win, vim.fn.winsaveview) ---@type vim.fn.winsaveview.ret
  view = { topline = view.topline, lnum = view.lnum } --[[@as snacks.scroll.View]]
  states[win] = (states[win] and states[win].buf == buf) and states[win]
    or { animating = false, target = vim.deepcopy(view), current = vim.deepcopy(view), buf = buf }
  states[win].view = view
  return states[win]
end

function M.setup()
  if config.debug then
    M.debug()
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

--- Check if we need to animate the scroll
---@param win number
function M.update(win)
  local state = get_state(win)
  if not state then
    return
  end

  if state.animating then
    -- triggered by the animation
    state.animating = false
    stats.animating = stats.animating + 1
    state.current = vim.deepcopy(state.view)
    return
  end

  local function update(changes)
    if not vim.api.nvim_win_is_valid(win) then
      return
    end
    -- if changes and changes.topline then
    --   dd(changes.topline)
    -- end
    state.current = changes and vim.tbl_extend("force", state.current, changes) or state.current
    -- don't process scroll events from animating
    state.animating = state.current.topline ~= state.view.topline
    -- always restore view, since it might be a lnum change
    vim.api.nvim_win_call(win, function()
      vim.fn.winrestview(state.current)
    end)
  end

  stats.targets = stats.targets + 1
  -- record new target
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
