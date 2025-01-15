---@class snacks.scroll
local M = {}

M.meta = {
  desc = "Smooth scrolling",
  needs_setup = true,
}

---@alias snacks.scroll.View {topline:number, lnum:number}

---@class snacks.scroll.State
---@field anim? snacks.animate.Animation
---@field win number
---@field buf number
---@field view vim.fn.winsaveview.ret
---@field current vim.fn.winsaveview.ret
---@field target vim.fn.winsaveview.ret
---@field scrolloff number
---@field virtualedit? string
---@field changedtick number
---@field last number vim.uv.hrtime of last scroll

---@class snacks.scroll.Config
---@field animate snacks.animate.Config|{}
---@field animate_repeat snacks.animate.Config|{}|{delay:number}
local defaults = {
  animate = {
    duration = { step = 15, total = 250 },
    easing = "linear",
  },
  -- faster animation when repeating scroll after delay
  animate_repeat = {
    delay = 100, -- delay in ms before using the repeat animation
    duration = { step = 5, total = 50 },
    easing = "linear",
  },
  -- what buffers to animate
  filter = function(buf)
    return vim.g.snacks_scroll ~= false and vim.b[buf].snacks_scroll ~= false and vim.bo[buf].buftype ~= "terminal"
  end,
  debug = false,
}

local SCROLL_UP, SCROLL_DOWN = Snacks.util.keycode("<c-e>"), Snacks.util.keycode("<c-y>")
local mouse_scrolling = false

M.enabled = false

local states = {} ---@type table<number, snacks.scroll.State>
local uv = vim.uv or vim.loop
local stats = { targets = 0, animating = 0, reset = 0, skipped = 0, mousescroll = 0, scrolls = 0 }
local config = Snacks.config.get("scroll", defaults)
local debug_timer = assert((vim.uv or vim.loop).new_timer())

-- get the state for a window.
-- when the state doesn't exist, its target is the current view
local function get_state(win)
  if vim.o.paste or vim.fn.reg_executing() ~= "" or vim.fn.reg_recording() ~= "" then
    return
  end
  if not vim.api.nvim_win_is_valid(win) then
    return
  end
  local buf = vim.api.nvim_win_get_buf(win)
  if not config.filter(buf) then
    return
  end
  if not Snacks.animate.enabled({ buf = buf, name = "scroll" }) then
    return
  end
  local changedtick = vim.api.nvim_buf_get_changedtick(buf)
  local view = vim.api.nvim_win_call(win, vim.fn.winsaveview) ---@type vim.fn.winsaveview.ret
  if not (states[win] and states[win].buf == buf and states[win].changedtick == changedtick) then
    ---@diagnostic disable-next-line: missing-fields
    states[win] = {
      win = win,
      target = vim.deepcopy(view),
      current = vim.deepcopy(view),
      buf = buf,
      changedtick = changedtick,
      last = 0,
    }
  end
  states[win].scrolloff = vim.wo[win].scrolloff
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

  -- track mouse scrolling
  Snacks.util.on_key("<ScrollWheelDown>", function()
    mouse_scrolling = true
  end)
  Snacks.util.on_key("<ScrollWheelUp>", function()
    mouse_scrolling = true
  end)

  -- initialize state for buffers entering windows
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    callback = vim.schedule_wrap(function(ev)
      for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
        get_state(win)
      end
    end),
  })

  -- update state when leaving insert mode or changing text in normal mode
  vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged" }, {
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
          local cursor = vim.api.nvim_win_get_cursor(win)
          states[win].current.lnum = cursor[1]
          states[win].current.col = cursor[2]
        end
      end
    end),
  })

  -- clear scroll state when leaving the cmdline after a search with incsearch
  vim.api.nvim_create_autocmd({ "CmdlineLeave" }, {
    group = group,
    callback = function(ev)
      if (ev.file == "/" or ev.file == "?") and vim.o.incsearch then
        for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
          states[win] = nil
        end
      end
    end,
  })

  -- listen to scroll events with topline changes
  vim.api.nvim_create_autocmd("WinScrolled", {
    group = group,
    callback = function()
      for win, changes in pairs(vim.v.event) do
        win = tonumber(win)
        if win and changes.topline ~= 0 then
          M.check(win)
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

---@param amount number
local function scroll(amount)
  if amount ~= 0 then
    vim.cmd(("normal! %d%s"):format(math.abs(amount), amount < 0 and SCROLL_UP or SCROLL_DOWN))
  end
end

---@param from number
---@param to number
local function visible_lines(from, to)
  from, to = math.min(from, to), math.max(from, to)
  local ret = 0
  while from < to do
    local fold_end = vim.fn.foldclosedend(from)
    ret = ret + (fold_end == -1 and 1 or 0)
    from = fold_end == -1 and from + 1 or fold_end + 1
  end
  return ret
end

---@param state snacks.scroll.State
---@param value? string
local function virtualedit(state, value)
  if value then
    state.virtualedit = state.virtualedit or vim.wo[state.win].virtualedit
    vim.wo[state.win].virtualedit = value
  elseif state.virtualedit then
    vim.wo[state.win].virtualedit = state.virtualedit
    state.virtualedit = nil
  end
end

--- Check if we need to animate the scroll
---@param win number
---@private
function M.check(win)
  local state = get_state(win)
  if not state then
    return
  end

  -- only animate the current window when scrollbind is enabled
  if vim.wo[state.win].scrollbind and vim.api.nvim_get_current_win() ~= state.win then
    return
  end

  -- if delta is 0, then we're animating.
  -- also skip if the difference is less than the mousescroll value,
  -- since most terminals support smooth mouse scrolling.
  if math.abs(state.view.topline - state.current.topline) <= 1 then
    stats.skipped = stats.skipped + 1
    state.current = vim.deepcopy(state.view)
    return
  elseif mouse_scrolling then
    if state.anim then
      state.anim:stop()
      state.anim = nil
      virtualedit(state) -- restore virtualedit
    end
    mouse_scrolling = false
    stats.mousescroll = stats.mousescroll + 1
    state.current = vim.deepcopy(state.view)
    return
  end
  stats.scrolls = stats.scrolls + 1

  -- new target
  stats.targets = stats.targets + 1
  state.target = vim.deepcopy(state.view)
  virtualedit(state, "all")

  local now = uv.hrtime()
  local repeat_delta = (now - state.last) / 1e6
  state.last = now

  ---@type snacks.animate.Opts
  local opts = vim.tbl_extend(
    "force",
    vim.deepcopy(repeat_delta <= config.animate_repeat.delay and config.animate_repeat or config.animate),
    {
      int = true,
      id = ("scroll_%d"):format(win),
      buf = state.buf,
    }
  )

  local scrolls = 0
  local from_virtcol, to_virtcol = 0, 0
  vim.api.nvim_win_call(state.win, function()
    -- reset to current state
    vim.fn.winrestview(state.current)
    state.current = vim.fn.winsaveview()
    -- calculate the amount of lines to scroll, taking folds into account
    scrolls = visible_lines(state.current.topline, state.target.topline)
    scrolls = scrolls * (state.target.topline > state.current.topline and -1 or 1)
    from_virtcol = vim.fn.virtcol({ state.current.lnum, state.current.col })
    to_virtcol = vim.fn.virtcol({ state.target.lnum, state.target.col })
  end)

  local from_lnum = state.current.lnum

  state.anim = Snacks.animate(0, scrolls, function(value, ctx)
    if not vim.api.nvim_win_is_valid(win) then
      return
    end
    vim.api.nvim_win_call(win, function()
      scroll(value - ctx.prev)

      if ctx.done then
        vim.fn.winrestview(state.target)
        state.current = vim.fn.winsaveview()
        virtualedit(state) -- restore virtualedit
        return
      end

      local info = vim.fn.getwininfo(state.win)[1]
      if state.scrolloff < (info.botline - info.topline) / 2 then
        local lnum = math.floor(from_lnum + (state.target.lnum - from_lnum) * value / scrolls + 0.5)

        -- adjust for scrolloff
        local top = info.topline == 1 and 1 or info.topline + state.scrolloff
        local bot = info.botline == info.height and info.height or info.botline - state.scrolloff
        lnum = math.max(top, math.min(lnum, bot))

        -- only move the cursor when the line is visible
        if vim.fn.foldclosed(lnum) == -1 then
          local virtcol = math.floor(from_virtcol + (to_virtcol - from_virtcol) * value / scrolls + 0.5)
          pcall(vim.api.nvim_win_set_cursor, state.win, { lnum, virtcol })
        end
      end
      local old = state.current
      state.current = vim.fn.winsaveview()

      -- this should never happen, but just in case
      if state.current.topline ~= info.topline then
        state.current = old
        vim.fn.winrestview(state.current)
      end
    end)
  end, opts)
end

---@private
function M.debug()
  if debug_timer:is_active() then
    return debug_timer:stop()
  end
  local last = {}
  debug_timer:start(50, 50, function()
    local data = vim.tbl_extend("force", { stats = stats }, states)
    for key, value in pairs(data) do
      if not vim.deep_equal(last[key], value) then
        Snacks.notify(vim.inspect(value), {
          ft = "lua",
          id = "snacks_scroll_debug_" .. key,
          title = "Snacks Scroll Debug " .. key,
        })
      end
    end
    last = vim.deepcopy(data)
  end)
end

return M
