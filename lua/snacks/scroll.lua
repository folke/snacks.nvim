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
---@field changedtick number
---@field last number vim.uv.hrtime of last scroll
---@field _wo vim.wo Backup of window options
local State = {}
State.__index = State

---@class snacks.scroll.Config
---@field animate snacks.animate.Config|{}
---@field animate_repeat snacks.animate.Config|{}|{delay:number}
local defaults = {
  animate = {
    duration = { step = 10, total = 200 },
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

local mouse_scrolling = false

M.enabled = false
local SCROLL_UP, SCROLL_DOWN = Snacks.util.keycode("<c-y>"), Snacks.util.keycode("<c-e>")

local uv = vim.uv or vim.loop
local stats = { targets = 0, animating = 0, reset = 0, skipped = 0, mousescroll = 0, scrolls = 0 }
local config = Snacks.config.get("scroll", defaults)
local debug_timer = assert((vim.uv or vim.loop).new_timer())
local states = {} ---@type table<number, snacks.scroll.State>

local function is_enabled(buf)
  return M.enabled
    and buf
    and not vim.o.paste
    and vim.fn.reg_executing() == ""
    and vim.fn.reg_recording() == ""
    and config.filter(buf)
    and Snacks.animate.enabled({ buf = buf, name = "scroll" })
end

---@param win number
function State.get(win)
  local buf = vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win)
  if not buf or not is_enabled(buf) then
    states[win] = nil
    return nil
  end

  local view = vim.api.nvim_win_call(win, vim.fn.winsaveview) ---@type vim.fn.winsaveview.ret
  local ret = states[win]
  if not (ret and ret:valid()) then
    if ret then
      ret:stop()
    end
    ret = setmetatable({}, State)
    ret.buf = buf
    ret._wo = {}
    ret.changedtick = vim.api.nvim_buf_get_changedtick(buf)
    ret.current = vim.deepcopy(view)
    ret.last = 0
    ret.target = vim.deepcopy(view)
    ret.win = win
  end
  ret.scrolloff = ret._wo.scrolloff or vim.wo[win].scrolloff
  ret.view = view
  states[win] = ret
  return ret
end

function State:stop()
  self:wo() -- restore window options
  if self.anim then
    self.anim:stop()
    self.anim = nil
  end
end

--- Save or restore window options
---@param opts? vim.wo|{}
function State:wo(opts)
  if not opts then
    if vim.api.nvim_win_is_valid(self.win) then
      for k, v in pairs(self._wo) do
        vim.wo[self.win][k] = v
      end
    end
    self._wo = {}
    return
  else
    for k, v in pairs(opts) do
      self._wo[k] = self._wo[k] or vim.wo[self.win][k]
      vim.wo[self.win][k] = v
    end
  end
end

function State:valid()
  return M.enabled
    and states[self.win] == self
    and vim.api.nvim_win_is_valid(self.win)
    and vim.api.nvim_buf_is_valid(self.buf)
    and vim.api.nvim_win_get_buf(self.win) == self.buf
    and vim.api.nvim_buf_get_changedtick(self.buf) == self.changedtick
end

function State:update()
  if vim.api.nvim_win_is_valid(self.win) then
    self.current = vim.api.nvim_win_call(self.win, vim.fn.winsaveview)
  end
end

--- Reset the scroll state for a buffer
---@param win number
function State.reset(win)
  if states[win] then
    states[win]:stop()
    states[win] = nil
  end
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
    State.get(win)
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
        State.get(win)
      end
    end),
  })

  -- update state when leaving insert mode or changing text in normal mode
  vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged", "TextChangedI" }, {
    group = group,
    callback = function(ev)
      for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
        State.get(win)
      end
    end,
  })

  -- update current state on cursor move
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = group,
    callback = vim.schedule_wrap(function(ev)
      for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
        if states[win] then
          states[win]:update()
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
          State.reset(win)
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

--- Determines the amount of scrollable lines between two window views,
--- taking folds and virtual lines into account.
---@param from vim.fn.winsaveview.ret
---@param to vim.fn.winsaveview.ret
local function scroll_lines(win, from, to)
  if from.topline == to.topline then
    return math.abs(from.topfill - to.topfill)
  end
  if to.topline < from.topline then
    from, to = to, from
  end
  local start_row, end_row, offset = from.topline - 1, to.topline - 1, 0
  if from.topfill > 0 then
    start_row = start_row + 1
    offset = from.topfill + 1
  end
  if to.topfill > 0 then
    offset = offset - to.topfill
  end
  if not vim.api.nvim_win_text_height then
    return end_row - start_row + offset
  end
  return vim.api.nvim_win_text_height(win, { start_row = start_row, end_row = end_row }).all + offset - 1
end

--- Check if we need to animate the scroll
---@param win number
---@private
function M.check(win)
  local state = State.get(win)
  if not state then
    return
  end

  -- only animate the current window when scrollbind is enabled
  if vim.wo[state.win].scrollbind and vim.api.nvim_get_current_win() ~= state.win then
    state:stop()
    return
  end

  -- if delta is 0, then we're animating.
  -- also skip if the difference is less than the mousescroll value,
  -- since most terminals support smooth mouse scrolling.
  if mouse_scrolling then
    state:stop()
    mouse_scrolling = false
    stats.mousescroll = stats.mousescroll + 1
    state.current = vim.deepcopy(state.view)
    return
  elseif math.abs(state.view.topline - state.current.topline) <= 1 then
    stats.skipped = stats.skipped + 1
    state.current = vim.deepcopy(state.view)
    return
  end
  stats.scrolls = stats.scrolls + 1

  -- new target
  stats.targets = stats.targets + 1
  state.target = vim.deepcopy(state.view)
  state:stop() -- stop any ongoing animation
  state:wo({ virtualedit = "all", scrolloff = 0 })

  local now = uv.hrtime()
  local repeat_delta = (now - state.last) / 1e6
  state.last = now

  local is_repeat = repeat_delta <= config.animate_repeat.delay
  ---@type snacks.animate.Opts
  local opts = vim.tbl_extend("force", vim.deepcopy(is_repeat and config.animate_repeat or config.animate), {
    int = true,
    id = ("scroll%s%d"):format(is_repeat and "_repeat_" or "_", win),
    buf = state.buf,
  })

  local scrolls = 0
  local col_from, col_to = 0, 0
  local move_from, move_to = 0, 0
  vim.api.nvim_win_call(state.win, function()
    move_to = vim.fn.winline()
    vim.fn.winrestview(state.current) -- reset to current state
    move_from = vim.fn.winline()
    state:update()
    -- calculate the amount of lines to scroll, taking folds into account
    scrolls = scroll_lines(state.win, state.current, state.target)
    col_from = vim.fn.virtcol({ state.current.lnum, state.current.col })
    col_to = vim.fn.virtcol({ state.target.lnum, state.target.col })
  end)

  local down = state.target.topline > state.current.topline
    or (state.target.topline == state.current.topline and state.target.topfill < state.current.topfill)

  local scrolled = 0

  state.anim = Snacks.animate(0, scrolls, function(value, ctx)
    if not state:valid() then
      state:stop()
      return
    end

    vim.api.nvim_win_call(win, function()
      if ctx.done then
        vim.fn.winrestview(state.target)
        state:update()
        state:stop()
        return
      end

      local count = vim.v.count -- backup count
      local commands = {} ---@type string[]

      -- scroll
      local scroll_target = math.floor(value)
      local scroll = scroll_target - scrolled --[[@as number]]
      if scroll > 0 then
        scrolled = scrolled + scroll
        commands[#commands + 1] = ("%d%s"):format(scroll, down and SCROLL_DOWN or SCROLL_UP)
      end

      -- move the cursor vertically
      local move = math.floor(value * math.abs(move_to - move_from) / scrolls) -- delta to move this step
      local move_target = move_from + ((move_to < move_from) and -1 or 1) * move -- target line
      commands[#commands + 1] = ("%dH"):format(move_target)

      -- move the cursor horizontally
      local virtcol = math.floor(col_from + (col_to - col_from) * value / scrolls)
      commands[#commands + 1] = ("%d|"):format(virtcol + 1)

      -- execute all commands in one go
      vim.cmd(("keepjumps normal! %s"):format(table.concat(commands, "")))

      -- restore count (see #1024)
      if vim.v.count ~= count then
        local cursor = vim.api.nvim_win_get_cursor(win)
        vim.cmd(("keepjumps normal! %dzh"):format(count))
        vim.api.nvim_win_set_cursor(win, cursor)
      end

      state:update()
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
