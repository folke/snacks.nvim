---@class snacks.win
---@field id number
---@field buf? number
---@field win? number
---@field opts snacks.win.Config
---@field augroup? number
---@field backdrop? snacks.win
---@overload fun(opts? :snacks.win.Config): snacks.win
local M = setmetatable({}, {
  __call = function(t, ...)
    return t.new(...)
  end,
})

---@class snacks.win.Keys: vim.api.keyset.keymap
---@field [1]? string
---@field [2]? string|fun(self: snacks.win): any
---@field mode? string|string[]

---@class snacks.win.Config: vim.api.keyset.win_config
---@field style? string merges with config from `Snacks.config.styles[style]`
---@field show? boolean Show the window immediately (default: true)
---@field height? number Height of the window. Use <1 for relative height. 0 means full height. (default: 0.9)
---@field width? number Width of the window. Use <1 for relative width. 0 means full width. (default: 0.9)
---@field minimal? boolean Disable a bunch of options to make the window minimal (default: true)
---@field position? "float"|"bottom"|"top"|"left"|"right"
---@field buf? number If set, use this buffer instead of creating a new one
---@field file? string If set, use this file instead of creating a new buffer
---@field enter? boolean Enter the window after opening (default: false)
---@field backdrop? number|false Opacity of the backdrop (default: 60)
---@field wo? vim.wo window options
---@field bo? vim.bo buffer options
---@field ft? string filetype to use for treesitter/syntax highlighting. Won't override existing filetype
---@field keys? table<string, false|string|fun(self: snacks.win)|snacks.win.Keys> Key mappings
---@field on_buf? fun(self: snacks.win) Callback after opening the buffer
---@field on_win? fun(self: snacks.win) Callback after opening the window
local defaults = {
  show = true,
  relative = "editor",
  position = "float",
  minimal = true,
  wo = {
    winhighlight = "Normal:SnacksNormal,NormalNC:SnacksNormalNC,WinBar:SnacksWinBar,WinBarNC:SnacksWinBarNC",
  },
  bo = {},
  keys = {
    q = "close",
  },
}

Snacks.config.style("float", {
  position = "float",
  backdrop = 60,
  height = 0.9,
  width = 0.9,
  zindex = 50,
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
    fillchars = "eob: ,lastline:…",
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

Snacks.util.set_hl({
  Backdrop = { bg = "#000000" },
  Normal = "NormalFloat",
  NormalNC = "NormalFloat",
  WinBar = "Title",
  WinBarNC = "SnacksWinBar",
}, { prefix = "Snacks", default = true })

M.transparent = false

local function check_bg()
  local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
  M.transparent = not (normal and normal.bg ~= nil)
end
check_bg()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("snacks_win_transparent", { clear = true }),
  callback = check_bg,
})

local id = 0

---@private
---@param ... snacks.win.Config|string
---@return snacks.win.Config
function M.resolve(...)
  local done = {} ---@type string[]
  local merge = {} ---@type snacks.win.Config[]
  local stack = { ... }
  while #stack > 0 do
    local next = table.remove(stack)
    next = type(next) == "table" and next or vim.deepcopy(Snacks.config.styles[next])
    ---@cast next snacks.win.Config?
    if next then
      table.insert(merge, 1, next)
      if next.style and not vim.tbl_contains(done, next.style) then
        table.insert(done, next.style)
        table.insert(stack, next.style)
      end
    end
  end
  local ret = #merge == 0 and {} or #merge == 1 and merge[1] or vim.tbl_deep_extend("force", {}, unpack(merge))
  ret.style = nil
  return ret
end

---@param opts? snacks.win.Config
---@return snacks.win
function M.new(opts)
  local self = setmetatable({}, { __index = M })
  id = id + 1
  self.id = id
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
  ---@cast opts snacks.win.Config
  self.opts = opts
  if opts.show ~= false then
    self:show()
  end
  return self
end

function M:focus()
  if self:valid() then
    vim.api.nvim_set_current_win(self.win)
  end
end

---@param opts? { buf: boolean }
function M:close(opts)
  opts = opts or {}
  local wipe = opts.buf ~= false and not self.opts.buf and not self.opts.file

  local win = self.win
  local buf = wipe and self.buf
  self.win = nil
  if buf then
    self.buf = nil
  end

  vim.schedule(function()
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if buf and vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
    if self.augroup then
      pcall(vim.api.nvim_del_augroup_by_id, self.augroup)
      self.augroup = nil
    end
  end)
end

function M:hide()
  self:close({ buf = false })
end

function M:toggle()
  if self:valid() then
    self:hide()
  else
    self:show()
  end
end

---@private
function M:open_buf()
  if self.buf and vim.api.nvim_buf_is_valid(self.buf) then
    -- keep existing buffer
    self.buf = self.buf
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
    self.buf = vim.api.nvim_create_buf(false, true)
  end
  if vim.bo[self.buf].filetype == "" and not self.opts.bo.filetype then
    self.opts.bo.filetype = "snacks_win"
  end
  return self.buf
end

---@private
function M:open_win()
  local relative = self.opts.relative or "editor"
  local position = self.opts.position or "float"
  local enter = self.opts.enter == nil or self.opts.enter or false
  local opts = self:win_opts()
  if position == "float" then
    self.win = vim.api.nvim_open_win(self.buf, enter, opts)
  else
    local parent = self.opts.win or 0
    local vertical = position == "left" or position == "right"
    if parent == 0 then
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if
          vim.w[win].snacks_win
          and vim.w[win].snacks_win.relative == relative
          and vim.w[win].snacks_win.position == position
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
    vim.api.nvim_win_call(parent, function()
      vim.cmd("silent noswapfile " .. cmd .. " " .. size .. "split")
      vim.api.nvim_win_set_buf(0, self.buf)
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
  end, vim.api.nvim_list_wins())
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

function M:show()
  if self:valid() then
    self:update()
    return self
  end
  self.augroup = vim.api.nvim_create_augroup("snacks_win_" .. self.id, { clear = true })

  self:open_buf()

  -- OPTIM: prevent treesitter or syntax highlighting to attach on FileType if it's not already enabled
  local optim_hl = not vim.b[self.buf].ts_highlight and vim.bo[self.buf].syntax == ""
  vim.b[self.buf].ts_highlight = optim_hl or vim.b[self.buf].ts_highlight
  Snacks.util.bo(self.buf, self.opts.bo)
  vim.b[self.buf].ts_highlight = not optim_hl and vim.b[self.buf].ts_highlight or nil

  if self.opts.on_buf then
    self.opts.on_buf(self)
  end

  self:open_win()
  if M.transparent then
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

  vim.api.nvim_create_autocmd("VimResized", {
    group = self.augroup,
    callback = function()
      self:update()
    end,
  })
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = self.augroup,
    callback = function()
      if not self:win_valid() then
        return true
      end
      local buf = vim.api.nvim_win_get_buf(self.win)
      if buf == self.buf then
        return
      end
      -- another buffer was opened in this window
      -- find another window to swap with
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if win ~= self.win and vim.bo[vim.api.nvim_win_get_buf(win)].buftype == "" then
          vim.schedule(function()
            vim.api.nvim_win_set_buf(self.win, self.buf)
            vim.api.nvim_win_set_buf(win, buf)
            vim.api.nvim_set_current_win(win)
            vim.cmd.stopinsert()
          end)
          return
        end
      end
    end,
  })

  for key, spec in pairs(self.opts.keys) do
    if spec then
      if type(spec) == "string" then
        spec = { key, self[spec] and self[spec] or spec, desc = spec }
      elseif type(spec) == "function" then
        spec = { key, spec }
      end
      local opts = vim.deepcopy(spec)
      opts[1] = nil
      opts[2] = nil
      opts.mode = nil
      opts.buffer = self.buf
      opts.nowait = true
      local rhs = spec[2]
      if type(rhs) == "function" then
        rhs = function()
          return spec[2](self)
        end
      end
      ---@cast spec snacks.win.Keys
      vim.keymap.set(spec.mode or "n", spec[1], rhs, opts)
    end
  end

  self:drop()

  return self
end

function M:add_padding()
  self.opts.wo.statuscolumn = " "
  self.opts.wo.list = true
  self.opts.wo.listchars = ("eol: ," .. (self.opts.wo.listchars or "")):gsub(",$", "")
end

function M:is_floating()
  return self:valid() and vim.api.nvim_win_get_config(self.win).zindex ~= nil
end

---@private
function M:drop()
  -- don't show a backdrop for non-floating windows
  if
    M.transparent
    or not (self:is_floating() and self.opts.backdrop and self.opts.backdrop < 100 and vim.o.termguicolors)
  then
    return
  end

  self.backdrop = M.new({
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
      winhighlight = "Normal:SnacksBackdrop",
      winblend = self.opts.backdrop,
    },
    bo = {
      buftype = "nofile",
      filetype = "snacks_win_backdrop",
    },
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = self.augroup,
    pattern = self.win .. "",
    callback = function()
      if self.backdrop then
        self.backdrop:close()
        self.backdrop = nil
      end
    end,
  })
end

---@param from? number
---@param to? number
function M:lines(from, to)
  return self:buf_valid() and vim.api.nvim_buf_get_lines(self.buf, from or 0, to or -1, false) or {}
end

---@param from? number
---@param to? number
function M:text(from, to)
  return table.concat(self:lines(from, to), "\n")
end

function M:parent_size()
  return {
    height = self.opts.relative == "win" and vim.api.nvim_win_get_height(self.opts.win) or vim.o.lines,
    width = self.opts.relative == "win" and vim.api.nvim_win_get_width(self.opts.win) or vim.o.columns,
  }
end

---@private
function M:win_opts()
  local opts = {} ---@type vim.api.keyset.win_config
  for _, k in ipairs(win_opts) do
    opts[k] = self.opts[k]
  end
  local parent = self:parent_size()
  -- Special case for 0, which means 100%
  opts.height = opts.height == 0 and parent.height or opts.height
  opts.width = opts.width == 0 and parent.width or opts.width
  opts.height = math.floor(opts.height < 1 and parent.height * opts.height or opts.height)
  opts.width = math.floor(opts.width < 1 and parent.width * opts.width or opts.width)

  if opts.relative == "cursor" then
    return opts
  end
  local border_offset = self:has_border() and 2 or 0
  opts.row = opts.row or math.floor((parent.height - opts.height - border_offset) / 2)
  opts.col = opts.col or math.floor((parent.width - opts.width - border_offset) / 2)

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
  return self.opts.border and self.opts.border ~= "" and self.opts.border ~= "none"
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

return M
