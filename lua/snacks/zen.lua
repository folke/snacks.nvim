---@class snacks.zen
---@overload fun(opts: snacks.zen.Config): snacks.win
local M = setmetatable({}, {
  __call = function(M, ...)
    return M.zen(...)
  end,
})

M.meta = {
  desc = "Zen mode • distraction-free coding",
}

---@class snacks.zen.Config
local defaults = {
  -- You can add any `Snacks.toggle` id here.
  -- Toggle state is restored when the window is closed.
  -- Toggle config options are NOT merged.
  ---@type table<string, boolean>
  toggles = {
    dim = true,
    git_signs = false,
    mini_diff_signs = false,
    -- diagnostics = false,
    -- inlay_hints = false,
  },
  center = true, -- center the window
  show = {
    statusline = false, -- can only be shown when using the global statusline
    tabline = false,
  },
  ---@type snacks.win.Config
  win = { style = "zen" },
  --- Callback when the window is opened.
  ---@param win snacks.win
  on_open = function(win) end,
  --- Callback when the window is closed.
  ---@param win snacks.win
  on_close = function(win) end,
  --- Options for the `Snacks.zen.zoom()`
  ---@type snacks.zen.Config
  zoom = {
    toggles = {},
    center = false,
    show = { statusline = true, tabline = true },
    win = {
      backdrop = false,
      width = 0, -- full width
    },
  },
}

Snacks.config.style("zen", {
  enter = true,
  fixbuf = false,
  minimal = false,
  width = 120,
  height = 0,
  backdrop = { transparent = true, blend = 40 },
  keys = { q = false },
  zindex = 40,
  wo = {
    winhighlight = "NormalFloat:Normal",
  },
  w = {
    snacks_main = true,
  },
})

-- fullscreen indicator
-- only shown when the window is maximized
Snacks.config.style("zoom_indicator", {
  text = "▍ zoom  󰊓  ",
  minimal = true,
  enter = false,
  focusable = false,
  height = 1,
  row = 0,
  col = -1,
  backdrop = false,
})

Snacks.util.set_hl({
  Icon = "DiagnosticWarn",
}, { prefix = "SnacksZen", default = true })

---@param opts? {statusline: boolean, tabline: boolean}
local function get_main(opts)
  opts = opts or {}
  local bottom = vim.o.cmdheight + (opts.statusline and vim.o.laststatus == 3 and 1 or 0)
  local top = opts.tabline
      and ((vim.o.showtabline == 2 or (vim.o.showtabline == 1 and #vim.api.nvim_list_tabpages() > 1)) and 1 or 0)
    or 0
  ---@class snacks.zen.Main values are 0-indexed
  local ret = {
    width = vim.o.columns,
    row = top,
    height = vim.o.lines - top - bottom,
  }
  return ret
end

M.win = nil ---@type snacks.win?

---@param opts? snacks.zen.Config
function M.zen(opts)
  local toggles = opts and opts.toggles
  opts = Snacks.config.get("zen", defaults, opts)
  opts.toggles = toggles or opts.toggles

  -- close if already open
  if M.win and M.win:valid() then
    M.win:close()
    M.win = nil
    return
  end

  local parent_win = vim.api.nvim_get_current_win()
  local parent_zindex = vim.api.nvim_win_get_config(parent_win).zindex

  local buf = vim.api.nvim_get_current_buf()
  local win_opts = Snacks.win.resolve({ style = "zen" }, opts.win, { buf = buf })
  win_opts.zindex = parent_zindex and parent_zindex + 1 or win_opts.zindex

  if Snacks.util.is_transparent() and type(win_opts.backdrop) == "table" then
    win_opts.backdrop.transparent = false
  end

  local zoom_indicator ---@type snacks.win?
  local show_indicator = false

  -- calculate window size
  if win_opts.height == 0 and (opts.show.statusline or opts.show.tabline or vim.o.cmdheight > 0) then
    local main = get_main(opts.show)
    win_opts.row = main.row
    win_opts.height = function()
      return get_main(opts.show).height
    end
    if type(win_opts.backdrop) == "table" then
      win_opts.backdrop.win = win_opts.backdrop.win or {}
      win_opts.backdrop.win.row = win_opts.row
      win_opts.backdrop.win.height = win_opts.height
    end
    if win_opts.width == 0 then
      show_indicator = true
    end
  end

  -- create window
  local win = Snacks.win(win_opts)
  if opts.center and vim.bo[buf].buftype ~= "terminal" then
    vim.cmd([[norm! zz]])
  else
    local view = vim.api.nvim_win_call(parent_win, vim.fn.winsaveview)
    vim.api.nvim_win_call(win.win, function()
      vim.fn.winrestview(view)
    end)
  end
  M.win = win

  if show_indicator then
    zoom_indicator = Snacks.win({
      show = false,
      style = "zoom_indicator",
      zindex = win.opts.zindex + 1,
      wo = { winhighlight = "NormalFloat:SnacksZenIcon" },
    })
    zoom_indicator:open_buf()
    local lines = vim.api.nvim_buf_get_lines(zoom_indicator.buf, 0, -1, false)
    zoom_indicator.opts.width = vim.api.nvim_strwidth(lines[1] or "")
    zoom_indicator:show()
  end

  -- set toggle states
  ---@type {toggle: snacks.toggle.Class, state: unknown}[]
  local states = {}
  for id, state in pairs(opts.toggles) do
    local toggle = Snacks.toggle.get(id)
    if toggle then
      table.insert(states, { toggle = toggle, state = toggle:get() })
      toggle:set(state)
    end
  end
  opts.on_open(win)

  -- sync cursor with the parent window
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = win.augroup,
    callback = function()
      if win:win_valid() and vim.api.nvim_win_is_valid(parent_win) then
        vim.api.nvim_win_set_cursor(parent_win, vim.api.nvim_win_get_cursor(win.win))
      end
    end,
  })

  -- restore toggle states when window is closed
  win:on("WinClosed", function()
    if zoom_indicator then
      zoom_indicator:close()
    end
    for _, state in ipairs(states) do
      state.toggle:set(state.state)
    end
    opts.on_close(win)
  end, { win = true })

  -- update the buffer of the parent window
  -- when the zen buffer changes
  win:on("BufWinEnter", function()
    vim.api.nvim_win_set_buf(parent_win, win.buf)
  end)

  -- close when entering another window
  win:on("WinEnter", function()
    local w = vim.api.nvim_get_current_win()
    if w == win.win then
      return
    end
    -- exit if other window is not a floating window
    if vim.api.nvim_win_get_config(w).relative == "" then
      -- schedule so that WinClosed is properly triggered
      vim.schedule(function()
        win:close()
      end)
    end
  end)
  return win
end

---@param opts? snacks.zen.Config
function M.zoom(opts)
  opts = Snacks.config.get("zen", defaults, opts)
  return M.zen(opts and opts.zoom or nil)
end

return M
