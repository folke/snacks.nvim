---@class snacks.win
---@field id number
---@field buf? number
---@field scratch_buf? number
---@field win? number
---@field opts snacks.win.Config
---@field augroup? number
---@field backdrop? snacks.win
---@field keys snacks.win.Keys[]
---@field events (snacks.win.Event|{event:string|string[]})[]
---@field meta table<string, any>
---@field closed? boolean
---@overload fun(opts? :snacks.win.Config|{}): snacks.win
local M = setmetatable({}, {
  __call = function(t, ...)
    return t.new(...)
  end,
})
M.__index = M

M.meta = {
  desc = "Create and manage floating windows or splits",
}

---@class snacks.win.Keys: vim.api.keyset.keymap
---@field [1]? string
---@field [2]? string|string[]|fun(self: snacks.win): string?
---@field mode? string|string[]

---@class snacks.win.Event: vim.api.keyset.create_autocmd
---@field buf? true
---@field win? true
---@field callback? fun(self: snacks.win, ev:vim.api.keyset.create_autocmd.callback_args):boolean?

---@class snacks.win.Backdrop
---@field bg? string
---@field blend? number
---@field transparent? boolean defaults to true
---@field win? snacks.win.Config overrides the backdrop window config

---@class snacks.win.Dim
---@field width number width of the window, without borders
---@field height number height of the window, without borders
---@field row number row of the window (0-indexed)
---@field col number column of the window (0-indexed)
---@field border? boolean whether the window has a border

---@alias snacks.win.Action.fn fun(self: snacks.win):(boolean|string?)
---@alias snacks.win.Action.spec snacks.win.Action|snacks.win.Action.fn
---@class snacks.win.Action
---@field action snacks.win.Action.fn
---@field desc? string

---@class snacks.win.Config: vim.api.keyset.win_config
---@field style? string merges with config from `Snacks.config.styles[style]`
---@field show? boolean Show the window immediately (default: true)
---@field footer_keys? boolean Show keys footer (default: false)
---@field height? number|fun(self:snacks.win):number Height of the window. Use <1 for relative height. 0 means full height. (default: 0.9)
---@field width? number|fun(self:snacks.win):number Width of the window. Use <1 for relative width. 0 means full width. (default: 0.9)
---@field min_height? number Minimum height of the window
---@field max_height? number Maximum height of the window
---@field min_width? number Minimum width of the window
---@field max_width? number Maximum width of the window
---@field col? number|fun(self:snacks.win):number Column of the window. Use <1 for relative column. (default: center)
---@field row? number|fun(self:snacks.win):number Row of the window. Use <1 for relative row. (default: center)
---@field minimal? boolean Disable a bunch of options to make the window minimal (default: true)
---@field position? "float"|"bottom"|"top"|"left"|"right"|"current"
---@field border? "none"|"top"|"right"|"bottom"|"left"|"hpad"|"vpad"|"rounded"|"single"|"double"|"solid"|"shadow"|"bold"|string[]|false|true
---@field buf? number If set, use this buffer instead of creating a new one
---@field file? string If set, use this file instead of creating a new buffer
---@field enter? boolean Enter the window after opening (default: false)
---@field backdrop? number|false|snacks.win.Backdrop Opacity of the backdrop (default: 60)
---@field wo? vim.wo|{} window options
---@field bo? vim.bo|{} buffer options
---@field b? table<string, any> buffer local variables
---@field w? table<string, any> window local variables
---@field ft? string filetype to use for treesitter/syntax highlighting. Won't override existing filetype
---@field scratch_ft? string filetype to use for scratch buffers
---@field keys? table<string, false|string|fun(self: snacks.win)|snacks.win.Keys> Key mappings
---@field on_buf? fun(self: snacks.win) Callback after opening the buffer
---@field on_win? fun(self: snacks.win) Callback after opening the window
---@field on_close? fun(self: snacks.win) Callback after closing the window
---@field fixbuf? boolean don't allow other buffers to be opened in this window
---@field text? string|string[]|fun():(string[]|string) Initial lines to set in the buffer
---@field actions? table<string, snacks.win.Action.spec> Actions that can be used in key mappings
---@field resize? boolean Automatically resize the window when the editor is resized
---@field stack? boolean When enabled, multiple split windows with the same position will be stacked together (useful for terminals)
local defaults = {
  show = true,
  fixbuf = true,
  relative = "editor",
  position = "float",
  minimal = true,
  wo = {
    winhighlight = "Normal:SnacksNormal,NormalNC:SnacksNormalNC,WinBar:SnacksWinBar,WinBarNC:SnacksWinBarNC,FloatTitle:SnacksTitle,FloatFooter:SnacksFooter,WinSeparator:SnacksWinSeparator",
  },
  bo = {},
  title_pos = "center",
  keys = {
    q = "close",
  },
  footer_pos = "center",
  footer_keys = false,
}

Snacks.config.style("float", {
  position = "float",
  backdrop = 60,
  height = 0.9,
  width = 0.9,
  zindex = 50,
})

Snacks.config.style("help", {
  position = "float",
  backdrop = false,
  border = "top",
  row = -1,
  width = 0,
  height = 0.3,
})

Snacks.config.style("split", {
  position = "bottom",
  height = 0.4,
  width = 0.4,
})

Snacks.config.style("minimal", {
  wo = {
    cursorcolumn = false,
    cursorline = false,
    cursorlineopt = "both",
    colorcolumn = "",
    fillchars = "eob: ,lastline:…",
    foldcolumn = "0",
    list = false,
    listchars = "extends:…,tab:  ",
    number = false,
    relativenumber = false,
    signcolumn = "no",
    spell = false,
    winbar = "",
    statuscolumn = "",
    wrap = false,
    sidescrolloff = 0,
  },
})

local SCROLL_UP, SCROLL_DOWN = Snacks.util.keycode("<c-u>"), Snacks.util.keycode("<c-d>")

local split_commands = {
  editor = {
    top = "topleft",
    right = "vertical botright",
    bottom = "botright",
    left = "vertical topleft",
  },
  win = {
    top = "aboveleft",
    right = "vertical rightbelow",
    bottom = "belowright",
    left = "vertical leftabove",
  },
}

local win_opts = {
  "anchor",
  "border",
  "bufpos",
  "col",
  "external",
  "fixed",
  "focusable",
  "footer",
  "footer_pos",
  "height",
  "hide",
  "noautocmd",
  "relative",
  "row",
  "style",
  "title",
  "title_pos",
  "width",
  "win",
  "zindex",
}

---@type table<string, string[]>
local borders = {
  left = { "", "", "", "", "", "", "", "│" },
  right = { "", "", "", "│", "", "", "", "" },
  top = { "", "─", "", "", "", "", "", "" },
  bottom = { "", "", "", "", "", "─", "", "" },
  hpad = { "", "", "", " ", "", "", "", " " },
  vpad = { "", " ", "", "", "", " ", "", "" },
}

Snacks.util.set_hl({
  Backdrop = { bg = "#000000" },
  Footer = "FloatFooter",
  FooterDesc = "DiagnosticInfo",
  FooterKey = "DiagnosticVirtualTextInfo",
  Normal = "NormalFloat",
  NormalNC = "NormalFloat",
  Title = "FloatTitle",
  WinBar = "Title",
  WinBarNC = "SnacksWinBar",
  WinKey = "Keyword",
  WinKeySep = "NonText",
  WinKeyDesc = "Function",
  WinSeparator = "WinSeparator",
}, { prefix = "Snacks", default = true })

local id = 0
local event_stack = {} ---@type string[]

--@private
---@param ...? snacks.win.Config|string|{}
---@return snacks.win.Config
function M.resolve(...)
  local done = {} ---@type table<string, boolean>
  local merge = {} ---@type snacks.win.Config[]
  local stack = {}
  for i = 1, select("#", ...) do
    local next = select(i, ...) ---@type snacks.win.Config|string?
    if next then
      table.insert(stack, next)
    end
  end
  while #stack > 0 do
    local next = table.remove(stack)
    next = type(next) == "string" and Snacks.config.styles[next] or next
    ---@cast next snacks.win.Config?
    if next and type(next) == "table" then
      table.insert(merge, 1, next)
      if next.style and not done[next.style] then
        done[next.style] = true
        table.insert(stack, next.style)
      end
    end
  end
  local ret = #merge == 0 and {} or #merge == 1 and merge[1] or vim.tbl_deep_extend("force", {}, unpack(merge))
  ret.style = nil
  return ret
end

---@param opts? snacks.win.Config|{}
---@return snacks.win
function M.new(opts)
  local self = setmetatable({}, M)
  id = id + 1
  self.id = id
  self.meta = {}
  opts = M.resolve(Snacks.config.get("win", defaults), opts)
  if opts.minimal then
    opts = M.resolve("minimal", opts)
  end
  if opts.position == "float" then
    opts = M.resolve("float", opts)
  else
    opts = M.resolve("split", opts)
    local vertical = opts.position == "left" or opts.position == "right"
    opts.wo.winfixheight = not vertical
    opts.wo.winfixwidth = vertical
  end
  if opts.relative == "win" then
    opts.win = opts.win or vim.api.nvim_get_current_win()
  end

  self.keys = {}
  self.events = {}
  local done = {} ---@type table<string, snacks.win.Keys>
  for key, spec in pairs(opts.keys) do
    if spec then
      if type(spec) == "string" then
        spec = { key, spec, desc = spec }
      elseif type(spec) == "function" then
        spec = { key, spec }
      elseif type(spec) == "table" and spec[1] and not spec[2] then
        spec = vim.deepcopy(spec) -- deepcopy just in case
        spec[1], spec[2] = key, spec[1]
      end
      ---@cast spec snacks.win.Keys
      local lhs = Snacks.util.normkey(spec[1] or "")
      local mode = type(spec.mode) == "table" and spec.mode or { spec.mode or "n" }
      ---@cast mode string[]
      mode = #mode == 0 and { "n" } or mode
      for _, m in ipairs(mode) do
        local k = m .. ":" .. lhs
        if done[k] then
          Snacks.notify.warn(
            ("# Duplicate key mapping for `%s` mode=%s (check case):\n```lua\n%s\n```\n```lua\n%s\n```"):format(
              lhs,
              m,
              vim.inspect(done[k]),
              vim.inspect(spec)
            )
          )
        end
        done[k] = spec
      end
      table.insert(self.keys, spec)
    end
  end

  self:on("WinClosed", self.on_close, { win = true })

  -- update window size when resizing
  self:on("VimResized", self.on_resize)

  ---@cast opts snacks.win.Config
  self.opts = opts
  if opts.show ~= false then
    self:show()
  end
  return self
end

function M:on_resize()
  if self.opts.resize ~= false then
    self:update()
  end
end

---@param actions string|string[]
function M:execute(actions)
  return self:action(actions)()
end

---@param actions string|string[]
---@return (fun(): boolean|string?) action, string? desc
function M:action(actions)
  actions = type(actions) == "string" and { actions } or actions
  ---@cast actions string[]
  local desc = {} ---@type string[]
  for a, name in ipairs(actions) do
    desc[a] = name:gsub("_", " ")
    if self.opts.actions and self.opts.actions[name] then
      local action = self.opts.actions[name]
      desc[a] = type(action) == "table" and action.desc and action.desc or desc[a]
    end
  end
  return function()
    for _, name in ipairs(actions) do
      if self.opts.actions and self.opts.actions[name] then
        local a = self.opts.actions[name]
        local fn = type(a) == "function" and a or a.action
        local ret = fn(self)
        if ret then
          return type(ret) == "string" and ret or nil
        end
      elseif self[name] then
        self[name](self)
        return
      else
        return name
      end
    end
  end,
    table.concat(desc, ", ")
end

---@param opts? {col_width?: number, key_width?: number, win?: snacks.win.Config}
function M:toggle_help(opts)
  opts = opts or {}
  local col_width, key_width = opts.col_width or 30, opts.key_width or 10
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "snacks_win_help" then
      vim.api.nvim_win_close(win, true)
      return
    end
  end
  local ns = vim.api.nvim_create_namespace("snacks.win.help")
  local win = M.new(M.resolve({ style = "help" }, opts.win or {}, {
    show = false,
    focusable = false,
    zindex = self.opts.zindex + 1,
    bo = { filetype = "snacks_win_help" },
  }))
  self:on("WinClosed", function()
    win:close()
  end, { win = true })
  self:on("BufLeave", function()
    win:close()
  end, { buf = true })
  local dim = win:dim()

  -- NOTE: we use the actual buffer keymaps instead of self.keys,
  -- since we want to show all keymaps, not just the ones we've defined on the window
  local keys = {} ---@type vim.api.keyset.get_keymap[]
  vim.list_extend(keys, vim.api.nvim_buf_get_keymap(self.buf, "n"))
  vim.list_extend(keys, vim.api.nvim_buf_get_keymap(self.buf, "i"))
  table.sort(keys, function(a, b)
    return (a.desc or a.lhs or "") < (b.desc or b.lhs or "")
  end)

  local done = {} ---@type table<string, boolean>
  keys = vim.tbl_filter(function(keymap)
    local key = Snacks.util.normkey(keymap.lhs or "")
    if done[key] or (keymap.desc and keymap.desc:find("which%-key")) then
      return false
    end
    done[key] = true
    return true
  end, keys)

  local cols = math.floor((dim.width - 1) / col_width)
  local rows = math.ceil(#keys / cols)
  win.opts.height = rows
  local help = {} ---@type {[1]:string, [2]:string}[][]
  local row, col = 0, 1

  ---@param str string
  ---@param len number
  ---@param align? "left"|"right"
  local function trunc(str, len, align)
    local w = vim.api.nvim_strwidth(str)
    if w > len then
      return vim.fn.strcharpart(str, 0, len - 1) .. "…"
    end
    return align == "right" and (string.rep(" ", len - w) .. str) or (str .. string.rep(" ", len - w))
  end

  for _, keymap in ipairs(keys) do
    local key = Snacks.util.normkey(keymap.lhs or "")
    row = row + 1
    if row > rows then
      row, col = 1, col + 1
    end
    help[row] = help[row] or {}
    vim.list_extend(help[row], {
      { trunc(key, key_width, "right"), "SnacksWinKey" },
      { " " },
      { "➜", "SnacksWinKeySep" },
      { " " },
      { trunc(keymap.desc or "", col_width - key_width - 3), "SnacksWinKeyDesc" },
    })
  end
  win:show()
  for l, line in ipairs(help) do
    vim.api.nvim_buf_set_lines(win.buf, l - 1, l, false, { "" })
    vim.api.nvim_buf_set_extmark(win.buf, ns, l - 1, 0, {
      virt_text = line,
      virt_text_pos = "overlay",
    })
  end
end

---@param event string|string[]
---@param cb fun(self: snacks.win, ev:vim.api.keyset.create_autocmd.callback_args):boolean?
---@param opts? snacks.win.Event
function M:on(event, cb, opts)
  opts = opts or {}
  opts.callback = cb
  table.insert(self.events, vim.tbl_extend("keep", { event = event }, opts))
  if self:valid() then
    self:_on(event, opts)
  end
end

---@param event string|string[]
---@param opts snacks.win.Event
function M:_on(event, opts)
  local event_opts = {} ---@type vim.api.keyset.create_autocmd
  local skip = { "buf", "win", "event" }
  for k, v in pairs(opts) do
    if not vim.tbl_contains(skip, k) then
      event_opts[k] = v
    end
  end
  event_opts.group = event_opts.group or self.augroup
  event_opts.callback = function(ev)
    table.insert(event_stack, ev.event)
    local ok, err = pcall(opts.callback, self, ev)
    table.remove(event_stack)
    return not ok and error(err) or err
  end
  if event_opts.pattern or event_opts.buffer then
    -- don't alter the pattern or buffer
  elseif opts.win then
    event_opts.pattern = self.win .. ""
  elseif opts.buf then
    event_opts.buffer = self.buf
  end
  vim.api.nvim_create_autocmd(event, event_opts)
end

function M:focus()
  if self:valid() then
    vim.api.nvim_set_current_win(self.win)
  end
end

function M:redraw()
  if vim.api.nvim__redraw then
    vim.api.nvim__redraw({ win = self.win, valid = false, flush = true, cursor = false })
  else
    vim.cmd("redraw")
  end
end

---@param left? boolean
function M:hscroll(left)
  vim.api.nvim_win_call(self.win, function()
    vim.cmd(("normal! %s"):format(left and "zh" or "zl"))
  end)
end

---@param up? boolean
function M:scroll(up)
  vim.api.nvim_win_call(self.win, function()
    vim.cmd(("normal! %s"):format(up and SCROLL_UP or SCROLL_DOWN))
  end)
end

function M:destroy()
  pcall(function()
    self:close()
  end)
  self.events = {}
  self.keys = {}
  self.meta = {}
  -- self.opts = {}
end

---@param opts? { buf: boolean }
function M:close(opts)
  opts = opts or {}
  local wipe = opts.buf ~= false and self.buf == self.scratch_buf

  local win = self.win
  local buf = wipe and self.buf
  local scratch_buf = self.scratch_buf ~= self.buf and self.scratch_buf or nil
  self:on_close()

  self.win = nil
  if scratch_buf then
    self.scratch_buf = nil
  end
  if buf then
    self.buf = nil
  end

  local close = function()
    local errors = {} ---@type string[]
    if win and vim.api.nvim_win_is_valid(win) then
      local ok, err = pcall(vim.api.nvim_win_close, win, true)
      if not ok and (err and err:find("E444")) then
        -- last window, so creat a split and close it again
        vim.cmd("silent! vsplit")
        pcall(vim.api.nvim_win_close, win, true)
      elseif not ok then
        errors[#errors + 1] = err
      end
    end
    if buf and vim.api.nvim_buf_is_valid(buf) then
      local ok, err = pcall(vim.api.nvim_buf_delete, buf, { force = true })
      errors[#errors + 1] = not ok and err or nil
    end
    if scratch_buf and vim.api.nvim_buf_is_valid(scratch_buf) then
      local ok, err = pcall(vim.api.nvim_buf_delete, scratch_buf, { force = true })
      errors[#errors + 1] = not ok and err or nil
    end
    if self.augroup then
      pcall(vim.api.nvim_del_augroup_by_id, self.augroup)
      self.augroup = nil
    end
    if #errors > 0 then
      error(table.concat(errors, "\n"))
    end
  end
  local retries = 0
  local try_close ---@type fun()
  try_close = function()
    local ok, err = pcall(close)
    if ok or not err then
      return
    end

    -- command window is open
    if err:find("E11") then
      vim.defer_fn(try_close, 200)
      return
    end

    -- text lock
    if err:find("E565") and retries < 20 then
      retries = retries + 1
      vim.defer_fn(try_close, 50)
      return
    end

    if not ok then
      Snacks.notify.error("Failed to close window: " .. err)
    end
  end
  -- HACK: WinClosed is not recursive, so we need to schedule it
  -- if we're in a WinClosed event
  if vim.tbl_contains(event_stack, "WinClosed") or not pcall(close) then
    vim.schedule(try_close)
  end
end

function M:hide()
  self:close({ buf = false })
  return self
end

function M:toggle()
  if self:valid() then
    self:hide()
  else
    self:show()
  end
  return self
end

---@param title string|{[1]:string, [2]:string}[]
---@param pos? "center"|"left"|"right"
function M:set_title(title, pos)
  if not self:has_border() then
    return
  end
  if type(title) == "string" then
    title = vim.trim(title)
    if title ~= "" then
      -- HACK: add extra space when last char is non word
      -- like for icons etc
      if not title:sub(-1):match("%w") then
        title = title .. " "
      end
      title = " " .. title .. " "
    end
  elseif #title == 0 then
    title = ""
  end
  pos = pos or self.opts.title_pos or "center"
  if vim.deep_equal(self.opts.title, title) and self.opts.title_pos == pos then
    return
  end
  self.opts.title = title
  self.opts.title_pos = pos
  if not self:valid() then
    return
  end
  -- Don't try to update if the relative window is invalid.
  -- It will be fixed once a full update is done.
  local relative_win = vim.api.nvim_win_get_config(self.win).win
  if relative_win and not vim.api.nvim_win_is_valid(relative_win) then
    return
  end
  vim.api.nvim_win_set_config(self.win, {
    title = self.opts.title,
    title_pos = self.opts.title_pos,
  })
end

---@private
function M:open_buf()
  if self.buf and vim.api.nvim_buf_is_valid(self.buf) then
    -- keep existing buffer
    self.buf = self.buf
  elseif self.scratch_buf and vim.api.nvim_buf_is_valid(self.scratch_buf) then
    -- keep existing scratch buffer
    self.buf = self.scratch_buf
  elseif self.opts.file then
    self.buf = vim.fn.bufadd(self.opts.file)
    if not vim.api.nvim_buf_is_loaded(self.buf) then
      vim.bo[self.buf].readonly = true
      vim.bo[self.buf].swapfile = false
      vim.fn.bufload(self.buf)
      vim.bo[self.buf].modifiable = false
    end
  elseif self.opts.buf then
    self.buf = self.opts.buf
  else
    self:scratch()
  end
  return self.buf
end

function M:scratch()
  if self.buf == self.scratch_buf and self:buf_valid() then
    return
  end
  self.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[self.buf].swapfile = false
  self.scratch_buf = self.buf
  local text = type(self.opts.text) == "function" and self.opts.text() or self.opts.text
  text = type(text) == "string" and vim.split(text, "\n") or text
  if text then
    ---@cast text string[]
    vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, text)
  end
  if not self.opts.bo.filetype then
    if self.opts.scratch_ft then
      vim.bo[self.buf].filetype = self.opts.scratch_ft
    else
      vim.bo[self.buf].filetype = self.opts.bo.filetype or "snacks_win"
    end
    vim.bo[self.buf].syntax = ""
  end
  if self:win_valid() then
    vim.api.nvim_win_set_buf(self.win, self.buf)
  end
end

---@private
function M:open_win()
  local relative = self.opts.relative or "editor"
  local position = self.opts.position or "float"
  local enter = self.opts.enter == nil or self.opts.enter or false
  if self.opts.focusable == false then
    enter = false
  end
  local opts = self:win_opts()
  if position == "float" then
    self.win = vim.api.nvim_open_win(self.buf, enter, opts)
  elseif position == "current" then
    self.win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(self.win, self.buf)
  else --split
    local parent = self.opts.win and vim.api.nvim_win_is_valid(self.opts.win) and self.opts.win or 0
    local vertical = position == "left" or position == "right"
    -- When stacking is enabled, find an existing window with the same relative/position
    -- and stack the new window perpendicular to it instead of creating a new split
    if parent == 0 and self.opts.stack then
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if
          vim.w[win].snacks_win
          and vim.w[win].snacks_win.relative == relative
          and vim.w[win].snacks_win.position == position
          and vim.w[win].snacks_win.stack == true
        then
          parent = win
          relative = "win"
          position = vertical and "bottom" or "right"
          vertical = not vertical
          break
        end
      end
    end
    local cmd = split_commands[relative][position]
    local size = vertical and opts.width or opts.height
    local resize = ("%sresize %s"):format(vertical and "vertical " or "", size)
    vim.api.nvim_win_call(parent, function()
      vim.cmd("silent noswapfile " .. cmd .. " sbuffer " .. self.buf .. " | " .. resize)
      self.win = vim.api.nvim_get_current_win()
    end)
    if enter then
      vim.api.nvim_set_current_win(self.win)
    end
    vim.schedule(function()
      self:equalize()
    end)
  end
  vim.w[self.win].snacks_win = {
    id = self.id,
    position = self.opts.position,
    relative = self.opts.relative,
    stack = self.opts.stack,
  }
end

---@private
function M:equalize()
  if self:is_floating() then
    return
  end
  local all = vim.tbl_filter(function(win)
    return vim.w[win].snacks_win
      and vim.w[win].snacks_win.relative == self.opts.relative
      and vim.w[win].snacks_win.position == self.opts.position
  end, vim.api.nvim_tabpage_list_wins(0))
  if #all <= 1 then
    return
  end
  local vertical = self.opts.position == "left" or self.opts.position == "right"
  local parent_size = self:parent_size()[vertical and "height" or "width"]
  local size = math.floor(parent_size / #all)
  for _, win in ipairs(all) do
    vim.api.nvim_win_call(win, function()
      vim.cmd(("%s resize %s"):format(vertical and "horizontal" or "vertical", size))
    end)
  end
end

function M:update()
  if self:valid() then
    Snacks.util.bo(self.buf, self.opts.bo)
    Snacks.util.wo(self.win, self.opts.wo)
    if self:is_floating() then
      local opts = self:win_opts()
      opts.noautocmd = nil
      vim.api.nvim_win_set_config(self.win, opts)
    end
  end
end

function M:on_current_tab()
  return self:win_valid() and vim.api.nvim_get_current_tabpage() == vim.api.nvim_win_get_tabpage(self.win)
end

function M:show()
  if self:valid() then
    self:update()
    return self
  end
  self.augroup = vim.api.nvim_create_augroup("snacks_win_" .. self.id, { clear = true })

  self:open_buf()

  -- buffer local variables
  for k, v in pairs(self.opts.b or {}) do
    vim.b[self.buf][k] = v
  end

  -- OPTIM: prevent treesitter or syntax highlighting to attach on FileType if it's not already enabled
  local optim_hl = not vim.b[self.buf].ts_highlight and vim.bo[self.buf].syntax == ""
  vim.b[self.buf].ts_highlight = optim_hl or vim.b[self.buf].ts_highlight
  Snacks.util.bo(self.buf, self.opts.bo)
  vim.b[self.buf].ts_highlight = not optim_hl and vim.b[self.buf].ts_highlight or nil

  if self.opts.on_buf then
    self.opts.on_buf(self)
  end

  if self.opts.footer_keys then
    self.opts.footer = {}
    table.sort(self.keys, function(a, b)
      return a[1] < b[1]
    end)
    for _, key in ipairs(self.keys) do
      local keymap = vim.fn.keytrans(Snacks.util.keycode(key[1]))
      table.insert(self.opts.footer, { " ", "SnacksFooter" })
      table.insert(self.opts.footer, { " " .. keymap .. " ", "SnacksFooterKey" })
      table.insert(self.opts.footer, { " " .. (key.desc or keymap) .. " ", "SnacksFooterDesc" })
    end
    table.insert(self.opts.footer, { " ", "SnacksFooter" })
  end

  self:open_win()
  self.closed = false
  -- window local variables
  for k, v in pairs(self.opts.w or {}) do
    vim.w[self.win][k] = v
  end
  if Snacks.util.is_transparent() then
    self.opts.wo.winblend = 0
  end
  Snacks.util.wo(self.win, self.opts.wo)
  if self.opts.on_win then
    self.opts.on_win(self)
  end

  -- syntax highlighting
  local ft = self.opts.ft or vim.bo[self.buf].filetype
  if ft and not ft:find("^snacks_") and not vim.b[self.buf].ts_highlight and vim.bo[self.buf].syntax == "" then
    local lang = vim.treesitter.language.get_lang(ft)
    if not (lang and pcall(vim.treesitter.start, self.buf, lang)) then
      vim.bo[self.buf].syntax = ft
    end
  end

  for _, event in ipairs(self.events) do
    self:_on(event.event, event)
  end

  -- swap buffers when opening a new buffer in the same window
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = self.augroup,
    nested = true,
    callback = function()
      return self:fixbuf()
    end,
  })

  self:map()
  self:drop()

  return self
end

function M:fixbuf()
  -- window closes, so delete the autocmd
  if not self:win_valid() then
    return true
  end

  if not self:buf_valid() then
    return
  end

  if not self:on_current_tab() then
    return
  end

  local buf = vim.api.nvim_win_get_buf(self.win)

  -- same buffer
  if buf == self.buf then
    return
  end

  -- don't swap if fixbuf is disabled
  if self.opts.fixbuf == false then
    self.buf = buf
    -- update window options
    Snacks.util.wo(self.win, self.opts.wo)
    return
  end

  -- another buffer was opened in this window
  -- find another window to swap with
  local main ---@type number?
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local win_buf = vim.api.nvim_win_get_buf(win)
    local is_float = vim.api.nvim_win_get_config(win).zindex ~= nil
    if win ~= self.win and not is_float then
      if vim.bo[win_buf].buftype == "" or vim.b[win_buf].snacks_main or vim.w[win].snacks_main then
        main = win
        break
      end
    end
  end

  if main then
    vim.api.nvim_win_set_buf(self.win, self.buf)
    vim.api.nvim_win_set_buf(main, buf)
    vim.api.nvim_set_current_win(main)
    vim.cmd.stopinsert()
  else
    -- no main window found, so close this window
    vim.api.nvim_win_set_buf(self.win, self.buf)
    vim.schedule(function()
      vim.cmd.stopinsert()
      vim.cmd("sbuffer " .. buf)
      if self.win and vim.api.nvim_win_is_valid(self.win) then
        vim.api.nvim_win_close(self.win, true)
      end
    end)
  end
end

---@param buf number
function M:set_buf(buf)
  assert(self:valid(), "Window is not valid")
  self.buf = buf
  vim.api.nvim_win_set_buf(self.win, buf)
  Snacks.util.wo(self.win, self.opts.wo)
end

function M:map()
  if not self:buf_valid() then
    return
  end
  for _, spec in pairs(self.keys) do
    local opts = vim.deepcopy(spec)
    opts[1] = nil
    opts[2] = nil
    opts.mode = nil
    ---@diagnostic disable-next-line: cast-type-mismatch
    ---@cast opts vim.keymap.set.Opts
    opts.buffer = self.buf
    opts.nowait = true
    local rhs = spec[2]
    local is_action = type(rhs) == "string" or type(rhs) == "table"
    if is_action then
      local desc = spec.desc
      ---@cast rhs string|string[]
      rhs, desc = self:action(rhs)
      opts.desc = opts.desc or desc
    else
      rhs = function()
        return spec[2](self)
      end
    end
    spec.desc = spec.desc or opts.desc
    ---@cast spec snacks.win.Keys
    vim.keymap.set(spec.mode or "n", spec[1], rhs, opts)
  end
end

---@private
function M:on_close()
  -- close the backdrop
  if self.backdrop then
    self.backdrop:close()
    self.backdrop = nil
  end
  if self.closed then
    return
  end
  self.closed = true
  if self.opts.on_close then
    self.opts.on_close(self)
  end
  -- Go back to the previous window when closing,
  -- and it's the current window
  if vim.api.nvim_get_current_win() == self.win then
    pcall(vim.cmd.wincmd, "p")
  end
end

function M:add_padding()
  local listchars = vim.split(self.opts.wo.listchars or "", ",")
  listchars = vim.tbl_filter(function(s)
    return not s:find("eol:") and s ~= ""
  end, listchars)
  table.insert(listchars, "eol: ")
  self.opts.wo.listchars = table.concat(listchars, ",")
  self.opts.wo.list = true
  self.opts.wo.statuscolumn = " "
end

function M:is_floating()
  return self:valid() and vim.api.nvim_win_get_config(self.win).zindex ~= nil
end

---@private
function M:drop()
  if self.backdrop then
    self.backdrop:close()
    self.backdrop = nil
  end
  local backdrop = self.opts.backdrop
  if not backdrop then
    return
  end
  backdrop = type(backdrop) == "number" and { blend = backdrop } or backdrop
  backdrop = backdrop == true and {} or backdrop
  backdrop = vim.tbl_extend("force", { bg = "#000000", blend = 60, transparent = true }, backdrop)
  ---@cast backdrop snacks.win.Backdrop

  if
    (Snacks.util.is_transparent() and backdrop.transparent)
    or not vim.o.termguicolors
    or backdrop.blend == 100
    or not self:is_floating()
  then
    return
  end

  local bg, winblend = backdrop.bg or "#000000", backdrop.blend
  if not backdrop.transparent then
    if Snacks.util.is_transparent() then
      bg = nil
    else
      bg = Snacks.util.blend(Snacks.util.color("Normal", "bg"), bg, winblend / 100)
    end
    winblend = 0
  end

  local group = ("SnacksBackdrop_%s"):format(bg and bg:sub(2) or "T")
  vim.api.nvim_set_hl(0, group, { bg = bg })

  self.backdrop = M.new(M.resolve({
    enter = false,
    backdrop = false,
    relative = "editor",
    height = 0,
    width = 0,
    style = "minimal",
    border = "none",
    focusable = false,
    zindex = self.opts.zindex - 1,
    wo = {
      winhighlight = "Normal:" .. group,
      winblend = winblend,
      colorcolumn = "",
    },
    bo = {
      buftype = "nofile",
      filetype = "snacks_win_backdrop",
    },
  }, backdrop.win))
end

function M:line(line)
  return self:lines(line, line)[1] or ""
end

---@param from? number 1-indexed, inclusive
---@param to? number 1-indexed, inclusive
function M:lines(from, to)
  return self:buf_valid() and vim.api.nvim_buf_get_lines(self.buf, from and from - 1 or 0, to or -1, false) or {}
end

---@param from? number 1-indexed, inclusive
---@param to? number 1-indexed, inclusive
function M:text(from, to)
  return table.concat(self:lines(from, to), "\n")
end

---@return { height: number, width: number }
function M:parent_size()
  if self.opts.relative == "win" and vim.api.nvim_win_is_valid(self.opts.win) then
    return {
      height = vim.api.nvim_win_get_height(self.opts.win),
      width = vim.api.nvim_win_get_width(self.opts.win),
    }
  end
  return {
    height = vim.o.lines,
    width = vim.o.columns,
  }
end

---@private
function M:win_opts()
  local opts = {} ---@type vim.api.keyset.win_config
  for _, k in ipairs(win_opts) do
    opts[k] = self.opts[k]
  end

  local border = self:border()

  opts.border = border and (borders[border] or border) or "none"

  if opts.relative == "cursor" then
    self.opts.row = self.opts.row or 0
    self.opts.col = self.opts.col or 0
  end

  local dim = self:dim()
  opts.height, opts.width = dim.height, dim.width
  opts.row, opts.col = dim.row, dim.col

  if vim.fn.has("nvim-0.10") == 0 then
    opts.footer, opts.footer_pos = nil, nil
  end

  if border then
    opts.title_pos = opts.title and (opts.title_pos or "center") or nil
    opts.footer_pos = opts.footer and (opts.footer_pos or "center") or nil
  else
    opts.title, opts.footer = nil, nil
    opts.title_pos, opts.footer_pos = nil, nil
  end

  return opts
end

---@return { height: number, width: number }
function M:size()
  local opts = self:win_opts()
  local height = opts.height
  local width = opts.width
  if self:has_border() then
    height = height + 2
    width = width + 2
  end
  return { height = height, width = width }
end

function M:has_border()
  return self:border() ~= nil
end

function M.is_border(border)
  return border and border ~= "" and border ~= "none"
end

function M:border()
  if not M.is_border(self.opts.border) then
    return
  end

  if self.opts.border == true then
    local border ---@type string|string[]|nil
    pcall(function()
      border = vim.o.winborder
      border = border:find(",") and vim.split(border, ",") or border
    end)
    return M.is_border(border) and border or "rounded"
  end
  return self.opts.border
end

--- Calculate the size of the border
function M:border_size()
  -- The array specifies the eight
  -- chars building up the border in a clockwise fashion
  -- starting with the top-left corner.
  -- { "╔", "═" ,"╗", "║", "╝", "═", "╚", "║" }
  local border = self:border() or { "" }
  border = type(border) == "string" and borders[border] or border
  border = type(border) == "string" and { "x" } or border
  assert(type(border) == "table", "Invalid border type")
  ---@cast border string[]
  while #border < 8 do
    vim.list_extend(border, border)
  end
  -- remove border hl groups
  border = vim.tbl_map(function(b)
    return type(b) == "table" and b[1] or b
  end, border)
  local function size(from, to)
    for i = from, to do
      if border[i] ~= "" then
        return 1
      end
    end
    return 0
  end
  ---@type { top: number, right: number, bottom: number, left: number }
  return {
    top = size(1, 3),
    right = size(3, 5),
    bottom = size(5, 7),
    left = math.max(size(7, 8), size(1, 1)),
  }
end

function M:border_text_width()
  if not self:has_border() then
    return 0
  end
  local ret = 0
  for _, t in ipairs({ "title", "footer" }) do
    local str = self.opts[t] or {}
    str = type(str) == "string" and { str } or str
    ---@cast str (string|string[])[]
    ret = math.max(ret, #table.concat(
      vim.tbl_map(function(s)
        return type(s) == "string" and s or s[1]
      end, str),
      ""
    ))
  end
  return ret
end

function M:buf_valid()
  return self.buf and vim.api.nvim_buf_is_valid(self.buf)
end

function M:win_valid()
  return self.win and vim.api.nvim_win_is_valid(self.win)
end

function M:valid()
  return self:win_valid() and self:buf_valid() and vim.api.nvim_win_get_buf(self.win) == self.buf
end

---@param parent? snacks.win.Dim
function M:dim(parent)
  parent = parent or self:parent_size()
  ---@type snacks.win.Dim
  local ret = {
    height = 0,
    width = 0,
    col = 0,
    row = 0,
    border = self:has_border(),
  }

  ---@param s? number|fun(win:snacks.win):number? size
  ---@param ps number parent size
  local function size(s, ps, border_offset)
    s = type(s) == "function" and s(self) or s or 0
    ---@cast s number
    if s == 0 then -- full size
      return ps - border_offset
    elseif s < 1 then -- relative size
      return math.floor(ps * s) - border_offset
    end
    return s
  end

  ---@param p? number|fun(win:snacks.win):number? pos
  ---@param s number size
  ---@param ps number parent size
  local function pos(p, s, ps, border_from, border_to)
    p = type(p) == "function" and p(self) or p
    ---@cast p number?
    if self.opts.relative == "cursor" then
      return p or 0
    end
    if not p then -- center
      return math.floor((ps - s) / 2) - border_from
    end
    ---@cast p number
    if p < 0 then -- negative position
      return ps - s + p - border_from - border_to
    elseif p < 1 and p > 0 then -- relative position
      return math.floor(ps * p) + border_from
    end
    return p
  end

  local border = self:border_size()

  ret.height = size(self.opts.height, parent.height, border.top + border.bottom)
  ret.height = math.max(ret.height, self.opts.min_height or 0, 1)
  ret.height = math.min(ret.height, self.opts.max_height or ret.height, parent.height)
  ret.height = math.max(ret.height, 1)

  ret.width = size(self.opts.width, parent.width, border.left + border.right)
  ret.width = math.max(ret.width, self.opts.min_width or 0, 1)
  ret.width = math.min(ret.width, self.opts.max_width or ret.width, parent.width)
  ret.width = math.max(ret.width, 1)

  ret.row = pos(self.opts.row, ret.height, parent.height, border.top, border.bottom)
  ret.col = pos(self.opts.col, ret.width, parent.width, border.left, border.right)

  return ret
end

return M
