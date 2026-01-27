---@class snacks.scope
local M = {}

M.meta = {
  desc = "Scope detection, text objects and jumping based on treesitter or indent",
  needs_setup = true,
}

---@class snacks.scope.Opts: snacks.scope.Config,{}
---@field buf? number
---@field pos? {[1]:number, [2]:number} -- (1,0) indexed
---@field end_pos? {[1]:number, [2]:number} -- (1,0) indexed
---@field async? boolean run scope detection asynchronously (defaults to true)

---@class snacks.scope.TextObject: snacks.scope.Opts
---@field linewise? boolean if nil, use visual mode. Defaults to `false` when not in visual mode
---@field notify? boolean show a notification when no scope is found (defaults to true)

---@class snacks.scope.Jump: snacks.scope.Opts
---@field bottom? boolean if true, jump to the bottom of the scope, otherwise to the top
---@field notify? boolean show a notification when no scope is found (defaults to true)

---@alias snacks.scope.Attach.cb fun(win: number, buf: number, scope:snacks.scope.Scope?, prev:snacks.scope.Scope?)

---@class snacks.scope.Config
---@field max_size? number
---@field enabled? boolean
local defaults = {
  -- absolute minimum size of the scope.
  -- can be less if the scope is a top-level single line scope
  min_size = 2,
  -- try to expand the scope to this size
  max_size = nil,
  cursor = true, -- when true, the column of the cursor is used to determine the scope
  edge = true, -- include the edge of the scope (typically the line above and below with smaller indent)
  siblings = false, -- expand single line scopes with single line siblings
  -- what buffers to attach to
  filter = function(buf)
    return vim.bo[buf].buftype == "" and vim.b[buf].snacks_scope ~= false and vim.g.snacks_scope ~= false
  end,
  -- debounce scope detection in ms
  debounce = 30,
  treesitter = {
    -- detect scope based on treesitter.
    -- falls back to indent based detection if not available
    enabled = true,
    injections = true, -- include language injections when detecting scope (useful for languages like `vue`)
    ---@type string[]|{enabled?:boolean}
    blocks = {
      enabled = false, -- enable to use the following blocks
      "function_declaration",
      "function_definition",
      "method_declaration",
      "method_definition",
      "class_declaration",
      "class_definition",
      "do_statement",
      "while_statement",
      "repeat_statement",
      "if_statement",
      "for_statement",
    },
    -- these treesitter fields will be considered as blocks
    field_blocks = {
      "local_declaration",
    },
  },
  -- These keymaps will only be set if the `scope` plugin is enabled.
  -- Alternatively, you can set them manually in your config,
  -- using the `Snacks.scope.textobject` and `Snacks.scope.jump` functions.
  keys = {
    ---@type table<string, snacks.scope.TextObject|{desc?:string}|false>
    textobject = {
      ii = {
        min_size = 2, -- minimum size of the scope
        edge = false, -- inner scope
        cursor = false,
        treesitter = { blocks = { enabled = false } },
        desc = "inner scope",
      },
      ai = {
        cursor = false,
        min_size = 2, -- minimum size of the scope
        treesitter = { blocks = { enabled = false } },
        desc = "full scope",
      },
    },
    ---@type table<string, snacks.scope.Jump|{desc?:string}|false>
    jump = {
      ["[i"] = {
        min_size = 1, -- allow single line scopes
        bottom = false,
        cursor = false,
        edge = true,
        treesitter = { blocks = { enabled = false } },
        desc = "jump to top edge of scope",
      },
      ["]i"] = {
        min_size = 1, -- allow single line scopes
        bottom = true,
        cursor = false,
        edge = true,
        treesitter = { blocks = { enabled = false } },
        desc = "jump to bottom edge of scope",
      },
    },
  },
}

local id = 0

---@alias snacks.scope.scope {buf: number, from: number, to: number, indent?: number}

---@class snacks.scope.Scope
---@field buf number
---@field from number
---@field to number
---@field indent? number
---@field opts snacks.scope.Opts
local Scope = {}
Scope.__index = Scope

---@generic T: snacks.scope.Scope
---@param self T
---@param scope snacks.scope.scope
---@param opts snacks.scope.Opts
---@return T
function Scope:new(scope, opts)
  local ret = setmetatable(scope, { __index = self, __eq = self.__eq, __tostring = self.__tostring })
  ret.opts = opts
  return ret
end

function Scope:__eq(other)
  return other
    and self.buf == other.buf
    and self.from == other.from
    and self.to == other.to
    and self.indent == other.indent
end

---@generic T: snacks.scope.Scope
---@param self T
---@param opts snacks.scope.Opts
---@return T?
function Scope:find(opts)
  error("not implemented")
end

---@generic T: snacks.scope.Scope
---@param self T
---@return T?
function Scope:parent()
  error("not implemented")
end

---@generic T: snacks.scope.Scope
---@param self T
---@return T
function Scope:with_edge()
  error("not implemented")
end

---@generic T: snacks.scope.scope
---@param self T
---@return T
function Scope:inner()
  error("not implemented")
end

---@param line number
function Scope.get_indent(line)
  local ret = vim.fn.indent(line)
  return ret == -1 and nil or ret, line
end

---@generic T: snacks.scope.Scope
---@param self T
---@param opts {buf?: number, from?: number, to?: number, indent?: number}}
---@return T?
function Scope:with(opts)
  opts = vim.tbl_extend("keep", opts, self)
  return setmetatable(opts, getmetatable(self)) --[[ @as snacks.scope.Scope ]]
end

function Scope:size()
  return self.to - self.from + 1
end

function Scope:size_with_edge()
  return self:with_edge():size()
end

---@generic T: snacks.scope.Scope
---@param self T
---@return T?
function Scope:expand(line)
  local ret = self ---@type snacks.scope.Scope?
  while ret do
    if line >= ret.from and line <= ret.to then
      return ret
    end
    ret = ret:parent()
  end
end

---@class snacks.scope.IndentScope: snacks.scope.Scope
local IndentScope = setmetatable({}, Scope)
IndentScope.__index = IndentScope

---@param line number 1-indexed
---@param indent number
---@param up? boolean
function IndentScope._expand(line, indent, up)
  local next = up and vim.fn.prevnonblank or vim.fn.nextnonblank
  while line do
    local i, l = IndentScope.get_indent(next(line + (up and -1 or 1)))
    if (i or 0) == 0 or i < indent or l == 0 then
      return line
    end
    line = l
  end
  return line
end

-- Inner indent scope is all lines with higher indent than the current scope
function IndentScope:inner()
  local from, to, indent = nil, nil, math.huge
  for l = self.from, self.to do
    local i, il = IndentScope.get_indent(vim.fn.nextnonblank(l))
    if il == l then
      if i > self.indent then
        from = from or l
        to = l
        indent = math.min(indent, i)
      end
    end
  end
  return from and to and self:with({ from = from, to = to, indent = indent }) or self
end

function IndentScope:with_edge()
  if self.indent == 0 then
    return self
  end
  local before_i, before_l = Scope.get_indent(vim.fn.prevnonblank(self.from - 1))
  local after_i, after_l = Scope.get_indent(vim.fn.nextnonblank(self.to + 1))
  local indent = math.min(math.max(before_i or self.indent, after_i or self.indent), self.indent)
  local from = before_i and before_i == indent and before_l or self.from
  local to = after_i and after_i == indent and after_l or self.to
  if from == 0 or to == 0 or indent < 0 then
    return self
  end
  return self:with({ from = from, to = to, indent = indent })
end

---@param opts snacks.scope.Opts
function IndentScope:find(opts)
  local indent, line = Scope.get_indent(opts.pos[1])
  local prev_i, prev_l = Scope.get_indent(vim.fn.prevnonblank(line - 1))
  local next_i, next_l = Scope.get_indent(vim.fn.nextnonblank(line + 1))

  -- fix indent when line is empty
  if vim.fn.prevnonblank(line) ~= line then
    indent, line = Scope.get_indent(prev_i > next_i and prev_l or next_l)
    prev_i, prev_l = Scope.get_indent(vim.fn.prevnonblank(line - 1))
    next_i, next_l = Scope.get_indent(vim.fn.nextnonblank(line + 1))
  end

  if line == 0 then
    return
  end

  -- adjust line to the nearest indent block
  if prev_i <= indent and next_i > indent then
    -- at top edge
    line = next_l
    indent = next_i
  elseif next_i <= indent and prev_i > indent then
    -- at bottom edge
    line = prev_l
    indent = prev_i
  elseif next_i > indent and prev_i > indent then
    -- at edge of two blocks. Prefer the one below.
    line = next_l
    indent = next_i
  end

  if opts.cursor then
    indent = math.min(indent, vim.fn.virtcol(opts.pos) + 1)
  end

  -- expand to include bigger indents
  return IndentScope:new({
    buf = opts.buf,
    from = IndentScope._expand(line, indent, true),
    to = IndentScope._expand(line, indent, false),
    indent = indent,
  }, opts)
end

function IndentScope:parent()
  for i = self.indent - 1, 1, -1 do
    local u, d = IndentScope._expand(self.from, i, true), IndentScope._expand(self.to, i, false)
    if u ~= self.from or d ~= self.to then -- update only when expanded
      return self:with({ from = u, to = d, indent = i })
    end
  end
end

---@class snacks.scope.TSScope: snacks.scope.Scope
---@field node TSNode
local TSScope = setmetatable({}, Scope)
TSScope.__index = TSScope

-- Expand the scope to fill the range of the node
function TSScope:fill()
  local n = self.node
  local u, _, d = n:range()
  while n do
    local uu, _, dd = n:range()
    if uu == u and dd == d and not self:is_field(n) then
      self.node = n
    else
      break
    end
    n = n:parent()
  end
end

function TSScope:fix()
  self:fill()
  self.from, _, self.to = self.node:range()
  self.from, self.to = self.from + 1, self.to + 1
  self.indent = math.min(vim.fn.indent(self.from), vim.fn.indent(self.to))
  return self
end

---@param node? TSNode
function TSScope:is_field(node)
  node = node or self.node
  local parent = node:parent()
  parent = parent ~= node:tree():root() and parent or nil
  if not parent then
    return false
  end
  for child, field in parent:iter_children() do
    if child == node then
      return not (field == nil or vim.tbl_contains(self.opts.treesitter.field_blocks, field))
    end
  end
  error("node not found in parent")
end

function TSScope:with_edge()
  local ret = self ---@type snacks.scope.TSScope?
  while ret do
    if ret:size() >= 1 and not ret:is_field() then
      return ret
    end
    ret = ret:parent()
  end
  return self
end

function TSScope:root()
  if type(self.opts.treesitter.blocks) ~= "table" or not self.opts.treesitter.blocks.enabled then
    return self:fix()
  end
  local root = self.node --[[@as TSNode?]]
  while root do
    if vim.tbl_contains(self.opts.treesitter.blocks, root:type()) then
      return self:with({ node = root })
    end
    root = root:parent()
  end
  return self:fix()
end

---@param opts {buf?: number, from?: number, to?: number, indent?: number, node?: TSNode}}
function TSScope:with(opts)
  local ret = Scope.with(self, opts) --[[ @as snacks.scope.TSScope ]]
  return ret:fix()
end

---@param opts snacks.scope.Opts
function TSScope:parser(opts)
  local lang = vim.bo[opts.buf].filetype
  local has_parser, parser = pcall(vim.treesitter.get_parser, opts.buf, lang, { error = false })
  return has_parser and parser or nil
end

---@param cb fun()
---@param opts snacks.scope.Opts
function TSScope:init(cb, opts)
  local parser = self:parser(opts)
  if not parser then
    return cb()
  end
  if opts.async == false then
    parser:parse()
    cb()
  else
    Snacks.util.parse(parser, opts.treesitter.injections, cb)
  end
end

---@param opts snacks.scope.Opts
function TSScope:find(opts)
  local lang = vim.treesitter.language.get_lang(vim.bo[opts.buf].filetype)
  local line = vim.fn.nextnonblank(opts.pos[1])
  line = line == 0 and vim.fn.prevnonblank(opts.pos[1]) or line
  -- FIXME:
  local pos = {
    math.max(line - 1, 0),
    (vim.fn.getline(line):find("%S") or 1) - 1, -- find first non-space character
  }

  local node = vim.treesitter.get_node({
    pos = pos,
    bufnr = opts.buf,
    lang = lang,
    ignore_injections = not opts.treesitter.injections,
  })
  if not node then
    return
  end

  if opts.cursor then
    -- expand to biggest ancestor with a lower start position
    local n = node ---@type TSNode?
    local virtcol = vim.fn.virtcol(opts.pos)
    while n and n ~= n:tree():root() do
      local r, c = n:range()
      local virtcol_n = vim.fn.virtcol({ r + 1, c })
      if virtcol_n > virtcol then
        node, n = n, n:parent()
      else
        break
      end
    end
  end

  local ret = TSScope:new({ buf = opts.buf, node = node }, opts):root()
  return ret
end

function TSScope:parent()
  local parent = self.node:parent()
  return parent and parent ~= self.node:tree():root() and self:with({ node = parent }):root() or nil
end

-- Inner treesitter scope includes all lines for which the node
-- has a start position lower than the start of the scope.
function TSScope:inner()
  local from, to, indent = nil, nil, math.huge
  for l = self.from + 1, self.to do
    if l == vim.fn.nextnonblank(l) then
      local col = (vim.fn.getline(l):find("%S") or 1) - 1
      local node = vim.treesitter.get_node({ pos = { l - 1, col }, bufnr = self.buf })
      local s = TSScope:new({ buf = self.buf, node = node }, self.opts):fix()
      if s and s.from > self.from and s.to <= self.to then
        from = from or l
        to = l
        indent = math.min(indent, vim.fn.indent(l))
      end
    end
  end
  return from and to and IndentScope:new({ from = from, to = to, indent = indent }, self.opts) or self
end

function Scope:__tostring()
  local meta = getmetatable(self)
  return ("%s(buf=%d, from=%d, to=%d, indent=%d)"):format(
    rawequal(meta, TSScope) and "TSScope" or rawequal(meta, IndentScope) and "IndentSCope" or "Scope",
    self.buf or -1,
    self.from or -1,
    self.to or -1,
    self.indent or 0
  )
end

---@param cb fun(scope?: snacks.scope.Scope)
---@param opts? snacks.scope.Opts|{parse?:boolean}
function M.get(cb, opts)
  opts = Snacks.config.get("scope", defaults, opts or {}) --[[ @as snacks.scope.Opts ]]
  opts.buf = (opts.buf == nil or opts.buf == 0) and vim.api.nvim_get_current_buf() or opts.buf
  if not opts.pos then
    assert(opts.buf == vim.api.nvim_win_get_buf(0), "missing pos")
    opts.pos = vim.api.nvim_win_get_cursor(0)
  end

  -- run in the context of the buffer if not current
  if vim.api.nvim_get_current_buf() ~= opts.buf then
    vim.api.nvim_buf_call(opts.buf, function()
      M.get(cb, opts)
    end)
    return
  end

  ---@type snacks.scope.Scope
  local Class = (opts.treesitter.enabled and Snacks.util.get_lang(opts.buf)) and TSScope or IndentScope
  if rawequal(Class, TSScope) and opts.parse ~= false then
    TSScope:init(function()
      opts.parse = false
      M.get(cb, opts)
    end, opts)
    return
  end
  local scope = Class:find(opts) --[[ @as snacks.scope.Scope? ]]

  -- fallback to indent based detection
  if not scope and rawequal(Class, TSScope) then
    Class = IndentScope
    scope = Class:find(opts)
  end

  -- when end_pos is provided, get its scope and expand the current scope
  -- to include it.
  if scope and opts.end_pos and not vim.deep_equal(opts.pos, opts.end_pos) then
    local end_scope = Class:find(vim.tbl_extend("keep", { pos = opts.end_pos }, opts)) --[[ @as snacks.scope.Scope? ]]
    if end_scope and end_scope.from < scope.from then
      scope = scope:expand(end_scope.from) or scope
    end
    if end_scope and end_scope.to > scope.to then
      scope = scope:expand(end_scope.to) or scope
    end
  end

  local min_size = opts.min_size or 2
  local max_size = opts.max_size or min_size

  -- expand block with ancestors until min_size is reached
  -- or max_size is reached
  if scope then
    local s = scope --- @type snacks.scope.Scope?
    while s do
      if opts.edge and scope:size_with_edge() >= min_size and s:size_with_edge() > max_size then
        break
      elseif not opts.edge and scope:size() >= min_size and s:size() > max_size then
        break
      end
      scope, s = s, s:parent()
    end
    -- expand with edge
    if opts.edge then
      scope = scope:with_edge() --[[@as snacks.scope.Scope]]
    end
  end

  -- expand single line blocks with single line siblings
  if opts.siblings and scope and scope:size() == 1 then
    while scope and scope:size() < min_size do
      local prev, next = vim.fn.prevnonblank(scope.from - 1), vim.fn.nextnonblank(scope.to + 1) ---@type number, number
      local prev_dist, next_dist = math.abs(opts.pos[1] - prev), math.abs(opts.pos[1] - next)
      local prev_s = prev > 0 and Class:find(vim.tbl_extend("keep", { pos = { prev, 0 } }, opts))
      local next_s = next > 0 and Class:find(vim.tbl_extend("keep", { pos = { next, 0 } }, opts))
      prev_s = prev_s and prev_s:size() == 1 and prev_s
      next_s = next_s and next_s:size() == 1 and next_s
      local s = prev_dist < next_dist and prev_s or next_s or prev_s
      if s and (s.from < scope.from or s.to > scope.to) then
        scope = Scope.with(scope, { from = math.min(scope.from, s.from), to = math.max(scope.to, s.to) })
      else
        break
      end
    end
  end
  cb(scope)
end

---@class snacks.scope.Listener
---@field id integer
---@field cb snacks.scope.Attach.cb
---@field opts snacks.scope.Config
---@field dirty table<number, boolean>
---@field timer uv.uv_timer_t
---@field augroup integer
---@field enabled boolean
---@field active table<number, snacks.scope.Scope>
local Listener = {}

---@param cb snacks.scope.Attach.cb
---@param opts? snacks.scope.Config
function Listener.new(cb, opts)
  local self = setmetatable({}, { __index = Listener })
  self.cb = cb
  self.dirty = {}
  self.timer = assert((vim.uv or vim.loop).new_timer())
  self.enabled = false
  self.opts = Snacks.config.get("scope", defaults, opts or {}) --[[ @as snacks.scope.Opts ]]
  id = id + 1
  self.id = id
  self.active = {}
  return self
end

--- Check if the scope has changed in the window / buffer
function Listener:check(win)
  local buf = vim.api.nvim_win_get_buf(win)
  if not self.opts.filter(buf) then
    if self.active[win] then
      local prev = self.active[win]
      self.active[win] = nil
      self.cb(win, buf, nil, prev)
    end
    return
  end

  M.get(
    function(scope)
      local prev = self.active[win]
      if prev == scope then
        return -- no change
      end
      self.active[win] = scope
      self.cb(win, buf, scope, prev)
    end,
    vim.tbl_extend("keep", {
      buf = buf,
      pos = vim.api.nvim_win_get_cursor(win),
    }, self.opts)
  )
end

--- Get the active scope for a window
function Listener:get(win)
  local scope = self.active[win]
  return scope and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == scope.buf and scope or nil
end

--- Cleanup invalid scopes
function Listener:clean()
  for win in pairs(self.active) do
    self.active[win] = self:get(win)
  end
end

--- Iterate over active scopes
function Listener:iter()
  self:clean()
  return pairs(self.active)
end

--- Schedule a scope update
---@param wins? number|number[]
---@param opts? {now?: boolean}
function Listener:update(wins, opts)
  wins = type(wins) == "number" and { wins } or wins or vim.api.nvim_list_wins() --[[ @as number[] ]]
  for _, b in ipairs(wins) do
    self.dirty[b] = true
  end
  local function update()
    self:_update()
  end
  if opts and opts.now then
    update()
  end
  self.timer:start(self.opts.debounce, 0, vim.schedule_wrap(update))
end

--- Process all pending updates
function Listener:_update()
  for win in pairs(self.dirty) do
    if vim.api.nvim_win_is_valid(win) then
      self:check(win)
    end
  end
  self.dirty = {}
end

--- Start listening for scope changes
function Listener:enable()
  assert(not self.enabled, "already enabled")
  self.enabled = true
  self.augroup = vim.api.nvim_create_augroup("snacks_scope_" .. self.id, { clear = true })
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = self.augroup,
    callback = function(ev)
      for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
        self:update(win)
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "WinClosed", "BufDelete", "BufWipeout" }, {
    group = self.augroup,
    callback = function()
      self:clean()
    end,
  })
  self:update(nil, { now = true })
end

--- Stop listening for scope changes
function Listener:disable()
  assert(self.enabled, "already disabled")
  self.enabled = false
  vim.api.nvim_del_augroup_by_id(self.augroup)
  self.timer:stop()
  self.active = {}
  self.dirty = {}
end

--- Attach a scope listener
---@param cb snacks.scope.Attach.cb
---@param opts? snacks.scope.Config
---@return snacks.scope.Listener
function M.attach(cb, opts)
  local ret = Listener.new(cb, opts)
  ret:enable()
  return ret
end

-- Text objects for indent scopes.
-- Best to use with Treesitter disabled.
-- When in visual mode, it will select the scope containing the visual selection.
-- When the scope is the same as the visual selection, it will select the parent scope instead.
---@param opts? snacks.scope.TextObject
function M.textobject(opts)
  opts = Snacks.config.get("scope", defaults, opts or {}) --[[ @as snacks.scope.TextObject ]]

  local mode = vim.fn.mode()
  local selection = mode:find("[vV]") ~= nil

  -- prepare for visual mode and determine linewise
  if mode == "v" then
    vim.cmd("normal! v")
  elseif mode == "V" then
    vim.cmd("normal! V")
    opts.linewise = opts.linewise == nil and true or opts.linewise
  end

  -- use the actual range instead of the cursor position
  -- in case of visual mode
  if selection then
    opts.pos = vim.api.nvim_buf_get_mark(0, "<")
    opts.end_pos = vim.api.nvim_buf_get_mark(0, ">")
  end
  local inner = not opts.edge
  opts.edge = true -- always include the edge of the scope to make inner work
  opts.async = false -- run synchronously

  M.get(function(scope)
    if not scope then
      return opts.notify ~= false and Snacks.notify.warn("No scope in range")
    end

    scope = inner and scope:inner() or scope
    -- determine scope range
    local from, to =
      { scope.from, opts.linewise and 0 or vim.fn.indent(scope.from) },
      { scope.to, opts.linewise and 0 or vim.fn.col({ scope.to, "$" }) - 2 }

    -- select the range
    vim.api.nvim_win_set_cursor(0, from)
    vim.cmd("normal! " .. (opts.linewise and "V" or "v"))
    vim.api.nvim_win_set_cursor(0, to)
  end, opts)
end

--- Jump to the top or bottom of the scope
--- If the scope is the same as the current scope, it will jump to the parent scope instead.
---@param opts? snacks.scope.Jump
function M.jump(opts)
  opts = Snacks.config.get("scope", defaults, opts or {}) --[[ @as snacks.scope.Jump ]]
  M.get(function(scope)
    if not scope then
      return opts.notify ~= false and Snacks.notify.warn("No scope in range")
    end
    while scope do
      local line = opts.bottom and scope.to or scope.from
      local pos = { line, vim.fn.indent(line) }
      if not vim.deep_equal(vim.api.nvim_win_get_cursor(0), pos) then
        return vim.api.nvim_win_set_cursor(0, { line, vim.fn.indent(line) })
      end
      scope = scope:parent()
    end
  end, opts)
end

---@private
function M.setup()
  local keys = Snacks.config.get("scope", defaults).keys
  for key, opts in pairs(keys.textobject) do
    if opts then
      vim.keymap.set({ "x", "o" }, key, function()
        M.textobject(opts)
      end, { silent = true, desc = opts.desc })
    end
  end
  for key, opts in pairs(keys.jump) do
    if opts then
      vim.keymap.set({ "n", "x", "o" }, key, function()
        M.jump(opts)
      end, { silent = true, desc = opts.desc })
    end
  end
end

M.TSScope = TSScope
M.IdentScope = IndentScope

return M
