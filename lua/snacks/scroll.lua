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

local mouse_scrolling = false

M.enabled = false
local SCROLL_UP, SCROLL_DOWN = Snacks.util.keycode("<c-y>"), Snacks.util.keycode("<c-e>")

local states = {} ---@type table<number, snacks.scroll.State>
local uv = vim.uv or vim.loop
local stats = { targets = 0, animating = 0, reset = 0, skipped = 0, mousescroll = 0, scrolls = 0 }
local config = Snacks.config.get("scroll", defaults)
local debug_timer = assert((vim.uv or vim.loop).new_timer())
local wo_backup = {} ---@type table<number, vim.wo>

---@param opts? vim.wo|{}
local function wo(win, opts)
  if not opts then
    for k, v in pairs(wo_backup[win] or {}) do
      vim.wo[win][k] = v
    end
    wo_backup[win] = nil
    return
  end
  wo_backup[win] = wo_backup[win] or {}
  for k, v in pairs(opts) do
    wo_backup[win][k] = wo_backup[win][k] or vim.wo[win][k]
    vim.wo[win][k] = v
  end
end

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
    -- go to target if we're still animating and resetting due to a change
    if states[win] and states[win].anim and not states[win].anim.done and states[win].buf == buf then
      states[win].anim:stop()
      states[win].anim = nil
      vim.api.nvim_win_call(win, function()
        vim.fn.winrestview(states[win].target)
      end)
      wo(win) -- restore window options
    end
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
  states[win].scrolloff = (wo_backup[win] or {}).scrolloff or vim.wo[win].scrolloff
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
  vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged", "TextChangedI" }, {
    group = group,
    callback = function(ev)
      for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
        get_state(win)
      end
    end,
  })

  -- update current state on cursor move
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = group,
    callback = vim.schedule_wrap(function(ev)
      for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
        if states[win] then
          local view = vim.api.nvim_win_call(win, vim.fn.winsaveview)
          states[win].current = view
          -- local cursor = vim.api.nvim_win_get_cursor(win)
          states[win].current.lnum = view.lnum
          states[win].current.col = view.col
          -- states[win].current.topline = view.topline
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
  if mouse_scrolling then
    if state.anim then
      state.anim:stop()
      state.anim = nil
      wo(win) -- restore window options
    end
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
  wo(win, { virtualedit = "all", scrolloff = 0 })

  local now = uv.hrtime()
  local repeat_delta = (now - state.last) / 1e6
  state.last = now

  ---@type snacks.animate.Opts
  local opts = vim.tbl_extend(
    "force",
    vim.deepcopy(repeat_delta <= config.animate_repeat.delay and config.animate_repeat or config.animate),
    {
      int = false,
      id = ("scroll_%d"):format(win),
      buf = state.buf,
    }
  )

  local scrolls = 0
  local col_from, col_to = 0, 0
  local move_from, move_to = 0, 0
  vim.api.nvim_win_call(state.win, function()
    move_to = vim.fn.winline()
    vim.fn.winrestview(state.current) -- reset to current state
    move_from = vim.fn.winline()
    state.current = vim.fn.winsaveview()
    -- calculate the amount of lines to scroll, taking folds into account
    scrolls = scroll_lines(state.win, state.current, state.target)
    col_from = vim.fn.virtcol({ state.current.lnum, state.current.col })
    col_to = vim.fn.virtcol({ state.target.lnum, state.target.col })
  end)

  local down = state.target.topline > state.current.topline
    or (state.target.topline == state.current.topline and state.target.topfill < state.current.topfill)

  local scrolled = 0

  state.anim = Snacks.animate(0, scrolls, function(value, ctx)
    if not vim.api.nvim_win_is_valid(win) then
      return
    end
    vim.api.nvim_win_call(win, function()
      if ctx.done then
        vim.fn.winrestview(state.target)
        state.current = vim.fn.winsaveview()
        wo(win) -- restore win options
        return
      end

      local count = vim.v.count -- backup count

      -- scroll
      local scroll_target = math.floor(value)
      local scroll = scroll_target - scrolled --[[@as number]]
      if scroll > 0 then
        scrolled = scrolled + scroll
        vim.cmd(("keepjumps normal! %d%s"):format(scroll, down and SCROLL_DOWN or SCROLL_UP))
      end

      -- move the cursor vertically
      local move = math.floor(value * math.abs(move_to - move_from) / scrolls) -- delta to move this step
      local move_target = move_from + ((move_to < move_from) and -1 or 1) * move -- target line
      vim.cmd(("keepjumps normal! %dH"):format(move_target))

      -- fix count
      if vim.v.count ~= count then
        vim.cmd(("keepjumps normal! %dzh"):format(count))
      end

      -- move the cursor horizontally
      local lnum = vim.api.nvim_win_get_cursor(win)[1]
      local virtcol = math.floor(col_from + (col_to - col_from) * value / scrolls + 0.5)
      local col = virtcol == 0 and 0 or vim.fn.virtcol2col(state.win, lnum, virtcol)
      vim.fn.winrestview({ col = col, coladd = math.max(virtcol - col, 0) })

      state.current = vim.fn.winsaveview()
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
