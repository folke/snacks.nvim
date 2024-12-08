---@class snacks.scope
local M = {}

---@class snacks.scope.Opts: snacks.scope.Config
---@field buf number
---@field pos {[1]:number, [2]:number} -- (1,0) indexed

---@alias snacks.scope.Attach.cb fun(win: number, buf: number, scope:snacks.scope.Scope?, prev:snacks.scope.Scope?)

---@class snacks.scope.Config
---@field max_size? number
local defaults = {
  -- absolute minimum size of the scope.
  -- can be less if the scope is a top-level single line scope
  min_size = 2,
  -- try to expand the scope to this size
  max_size = nil,
  siblings = false, -- expand single line scopes with single line siblings
  -- what buffers to attach to
  filter = function(buf)
    return vim.bo[buf].buftype == ""
  end,
  -- debounce scope detection in ms
  debounce = 30,
  treesitter = {
    -- detect scope based on treesitter.
    -- falls back to indent based detection if not available
    enabled = true,
    ---@type string[]|false
    blocks = {
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
  local ret = setmetatable(scope, { __index = self, __eq = self.__eq })
  ret.opts = opts
  return ret
end

function Scope:__eq(other)
  return other and self.buf == other.buf and self.from == other.from and self.to == other.to
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

---@class snacks.scope.IndentScope: snacks.scope.Scope
local IndentScope = setmetatable({}, Scope)
IndentScope.__index = IndentScope

---@param line number 1-indexed
---@param indent number
---@param up? boolean
function IndentScope.expand(line, indent, up)
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

function IndentScope:with_edge()
  if self.indent == 0 then
    return self
  end
  local before_i, before_l = Scope.get_indent(vim.fn.prevnonblank(self.from - 1))
  local after_i, after_l = Scope.get_indent(vim.fn.nextnonblank(self.to + 1))
  local indent = math.min(math.max(before_i or self.indent, after_i or self.indent), self.indent)
  local from = before_i and before_i == indent and before_l or self.from
  local to = after_i and after_i == indent and after_l or self.to
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
    line = next_l
    indent = next_i
  elseif next_i <= indent and prev_i > indent then
    line = prev_l
    indent = prev_i
  end

  -- expand to include bigger indents
  return IndentScope:new({
    buf = opts.buf,
    from = IndentScope.expand(line, indent, true),
    to = IndentScope.expand(line, indent, false),
    indent = indent,
  }, opts)
end

function IndentScope:parent()
  for i = self.indent - 1, 1, -1 do
    local u, d = IndentScope.expand(self.from, i, true), IndentScope.expand(self.to, i, false)
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
    if uu == u and dd == d then
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
  self.indent = math.huge
  local l = self.from
  while l and l > 0 and l <= self.to do
    self.indent = math.min(self.indent, vim.fn.indent(l))
    l = vim.fn.nextnonblank(l + 1)
  end
  self.indent = self.indent == math.huge and 0 or self.indent
  return self
end

function TSScope:with_edge()
  -- FIXME: this is incorrect if the scope is already at the edge
  local prev = vim.fn.prevnonblank(self.from - 1)
  local next = vim.fn.nextnonblank(self.from + 1)
  if vim.fn.indent(next) > self.indent then
    return self
  end
  local parent, ret = self:parent(), self
  while parent and parent.indent < self.indent do
    if parent.from >= prev then
      ret = parent
    end
    parent = parent:parent()
  end
  return ret
end

function TSScope:root()
  if self.opts.treesitter.blocks == false then
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
function TSScope:find(opts)
  if not vim.b[opts.buf].ts_highlight then
    return
  end
  local lang = vim.bo[opts.buf].filetype
  local has_parser, parser = pcall(vim.treesitter.get_parser, opts.buf, lang, { error = false })
  if not has_parser or parser == nil then
    return
  end

  local line = vim.fn.nextnonblank(opts.pos[1])
  line = line == 0 and vim.fn.prevnonblank(opts.pos[1]) or line
  -- FIXME:
  local pos = {
    math.max(line - 1, 0),
    (vim.fn.getline(line):find("%S") or 1) - 1, -- find first non-space character
  }

  local node = vim.treesitter.get_node({ pos = pos, bufnr = opts.buf, lang = lang })
  if not node then
    return
  end
  local ret = TSScope:new({ buf = opts.buf, node = node }, opts)
  return ret:root()
end

function TSScope:parent()
  local parent = self.node:parent()
  return parent and parent ~= self.node:tree():root() and self:with({ node = parent }):root() or nil
end

---@param opts? snacks.scope.Opts
---@return snacks.scope.Scope?
function M.get(opts)
  opts = opts or {}
  opts.buf = (opts.buf == nil or opts.buf == 0) and vim.api.nvim_get_current_buf() or opts.buf
  if not opts.pos then
    assert(opts.buf == vim.api.nvim_win_get_buf(0), "missing pos")
    opts.pos = vim.api.nvim_win_get_cursor(0)
  end

  -- run in the context of the buffer if not current
  if vim.api.nvim_get_current_buf() ~= opts.buf then
    return vim.api.nvim_buf_call(opts.buf, function()
      return M.get(opts)
    end)
  end

  ---@type snacks.scope.Scope
  local Class = opts.treesitter.enabled and vim.b[opts.buf].ts_highlight and TSScope or IndentScope
  local ret = Class:find(opts)

  -- fallback to indent based detection
  if not ret and Class == TSScope then
    Class = IndentScope
    ret = Class:find(opts)
  end

  local min_size = opts.min_size or 2
  local max_size = opts.max_size or min_size

  -- expand block with ancestors until min_size is reached
  -- or max_size is reached
  if ret then
    local s = ret --- @type snacks.scope.Scope?
    while s do
      if ret:size_with_edge() >= min_size and s:size_with_edge() > max_size then
        break
      end
      ret, s = s, s:parent()
    end
    -- expand with edge
    ret = ret:with_edge() --[[@as snacks.scope.Scope]]
  end

  -- expand single line blocks with single line siblings
  if opts.siblings and ret and ret:size() == 1 then
    while ret and ret:size() < min_size do
      local prev, next = vim.fn.prevnonblank(ret.from - 1), vim.fn.nextnonblank(ret.to + 1) ---@type number, number
      local prev_dist, next_dist = math.abs(opts.pos[1] - prev), math.abs(opts.pos[1] - next)
      local prev_s = prev > 0 and Class:find(vim.tbl_extend("keep", { pos = { prev, 0 } }, opts))
      local next_s = next > 0 and Class:find(vim.tbl_extend("keep", { pos = { next, 0 } }, opts))
      prev_s = prev_s and prev_s:size() == 1 and prev_s
      next_s = next_s and next_s:size() == 1 and next_s
      local s = prev_dist < next_dist and prev_s or next_s or prev_s
      if s then
        ret = Scope.with(ret, { from = math.min(ret.from, s.from), to = math.max(ret.to, s.to) })
      else
        break
      end
    end
  end

  return ret
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
    return
  end

  local scope = M.get(vim.tbl_extend("keep", {
    buf = buf,
    pos = vim.api.nvim_win_get_cursor(win),
  }, self.opts))
  local prev = self.active[win]
  if prev == scope then
    return -- no change
  end
  self.active[win] = scope
  self.cb(win, buf, scope, prev)
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

return M
