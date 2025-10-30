---@class snacks.picker.explorer.Node
---@field path string
---@field name string
---@field hidden? boolean
---@field status? string merged git status
---@field dir_status? string git status of the directory
---@field ignored? boolean
---@field type "file"|"directory"|"link"|"fifo"|"socket"|"char"|"block"|"unknown"
---@field dir? boolean
---@field open? boolean wether the node should be expanded (only for directories)
---@field expanded? boolean wether the node is expanded (only for directories)
---@field parent? snacks.picker.explorer.Node
---@field last? boolean child of the parent
---@field utime? number
---@field children table<string, snacks.picker.explorer.Node>
---@field severity? number

---@class snacks.picker.explorer.Filter
---@field hidden? boolean show hidden files
---@field ignored? boolean show ignored files
---@field exclude? string[] globs to exclude
---@field include? string[] globs to exclude

---@alias snacks.picker.explorer.Snapshot {fields: string[], state:table<snacks.picker.explorer.Node, any[]>}

local uv = vim.uv or vim.loop

local function norm(path)
  return svim.fs.normalize(path):gsub("/$", ""):gsub("^$", "/")
end

local function assert_dir(path)
  assert(vim.fn.isdirectory(path) == 1, "Not a directory: " .. path)
end

-- local function assert_file(path)
--   assert(vim.fn.filereadable(path) == 1, "Not a file: " .. path)
-- end

---@class snacks.picker.explorer.Tree
---@field root snacks.picker.explorer.Node
---@field nodes table<string, snacks.picker.explorer.Node>
local Tree = {}
Tree.__index = Tree

function Tree.new()
  local self = setmetatable({}, Tree)
  self.root = { name = "", children = {}, dir = true, type = "directory", path = "" }
  self.nodes = {}
  return self
end

---@param path string
---@return snacks.picker.explorer.Node?
function Tree:node(path)
  path = norm(path)
  return self.nodes[norm(path)]
end

---@param path string
function Tree:find(path)
  path = norm(path)
  if self.nodes[path] then
    return self.nodes[path]
  end

  local node = self.root
  local parts = vim.split(path, "/", { plain = true })
  local is_dir = vim.fn.isdirectory(path) == 1
  for p, part in ipairs(parts) do
    node = self:child(node, part, (is_dir or p < #parts) and "directory" or "file")
  end
  return node
end

---@param node snacks.picker.explorer.Node
---@param name string
---@param type string
function Tree:child(node, name, type)
  if not node.children[name] then
    local path = node.path .. "/" .. name
    path = node == self.root and name or path
    node.children[name] = {
      name = name,
      path = path,
      parent = node,
      children = {},
      type = type,
      dir = type == "directory" or (type == "link" and vim.fn.isdirectory(path) == 1),
      hidden = name:sub(1, 1) == ".",
    }
    self.nodes[path] = node.children[name]
  end
  return node.children[name]
end

---@param path string
function Tree:open(path)
  local dir = self:dir(path)
  local node = self:find(dir)
  while node do
    node.open = true
    node = node.parent
  end
end

---@param path string
function Tree:toggle(path)
  local dir = self:dir(path)
  local node = self:find(dir)
  if node.open then
    self:close(dir)
  else
    self:open(dir)
  end
end

---@param path string
function Tree:show(path)
  self:open(vim.fs.dirname(path))
end

---@param path string
function Tree:close(path)
  local dir = self:dir(path)
  local node = self:find(dir)
  node.open = false
  node.expanded = false -- clear expanded state
end

---@param node snacks.picker.explorer.Node
function Tree:expand(node)
  if node.expanded then
    return
  end
  local found = {} ---@type table<string, boolean>
  assert(node.dir, "Can only expand directories")
  local fs = uv.fs_scandir(node.path)
  while fs do
    local name, t = uv.fs_scandir_next(fs)
    if not name then
      break
    end
    t = t or Snacks.util.path_type(node.path .. "/" .. name)
    found[name] = true
    local child = self:child(node, name, t)
    child.type = t
    child.dir = t == "directory" or (t == "link" and vim.fn.isdirectory(child.path) == 1)
  end
  for name in pairs(node.children) do
    if not found[name] then
      node.children[name] = nil
    end
  end
  node.expanded = true
  node.utime = uv.hrtime()
end

---@param path string
function Tree:dir(path)
  return vim.fn.isdirectory(path) == 1 and path or vim.fs.dirname(path)
end

---@param path string
function Tree:refresh(path)
  local dir = self:dir(path)
  require("snacks.explorer.git").refresh(dir)
  local root = self:node(dir)
  if not root then
    return
  end
  self:walk(root, function(node)
    node.expanded = nil
  end, { all = true })
end

---@param node snacks.picker.explorer.Node
---@param fn fun(node: snacks.picker.explorer.Node):boolean? return `false` to not process children, `true` to abort
---@param opts? {all?: boolean}
function Tree:walk(node, fn, opts)
  local abort = false ---@type boolean?
  abort = fn(node)
  if abort ~= nil then
    return abort
  end
  local children = vim.tbl_values(node.children) ---@type snacks.picker.explorer.Node[]
  table.sort(children, function(a, b)
    if a.dir ~= b.dir then
      return a.dir
    end
    return a.name < b.name
  end)
  for c, child in ipairs(children) do
    child.last = c == #children
    abort = false
    if child.dir and (child.open or (opts and opts.all)) then
      abort = self:walk(child, fn, opts)
    else
      abort = fn(child)
    end
    if abort then
      return true
    end
  end
  return false
end

---@param filter snacks.picker.explorer.Filter
function Tree:filter(filter)
  local exclude = filter.exclude and #filter.exclude > 0 and Snacks.picker.util.globber(filter.exclude)
  local include = filter.include and #filter.include > 0 and Snacks.picker.util.globber(filter.include)
  return function(node)
    -- takes precedence over all other filters
    if include and include(node.path) then
      return true
    end
    if node.hidden and not filter.hidden then
      return false
    end
    if node.ignored and not filter.ignored then
      return false
    end
    if exclude and exclude(node.path) then
      return false
    end
    return true
  end
end

---@param cwd string
---@param cb fun(node: snacks.picker.explorer.Node)
---@param opts? {expand?: boolean}|snacks.picker.explorer.Filter
function Tree:get(cwd, cb, opts)
  opts = opts or {}
  assert_dir(cwd)
  local node = self:find(cwd)
  node.open = true
  local filter = self:filter(opts)
  self:walk(node, function(n)
    if n ~= node then
      if not filter(n) then
        return false
      end
    end
    if n.dir and n.open and not n.expanded and opts.expand ~= false then
      self:expand(n)
    end
    cb(n)
  end)
end

---@param cwd string
---@param opts? snacks.picker.explorer.Filter
function Tree:is_dirty(cwd, opts)
  opts = opts or {}
  if require("snacks.explorer.git").is_dirty(cwd) then
    return true
  end
  local dirty = false
  self:get(cwd, function(n)
    if n.dir and n.open and not n.expanded then
      dirty = true
    end
  end, { hidden = opts.hidden, ignored = opts.ignored, exclude = opts.exclude, include = opts.include, expand = false })
  return dirty
end

---@param cwd string
---@param path string
function Tree:in_cwd(cwd, path)
  local dir = vim.fs.dirname(path)
  return dir == cwd or dir:find(cwd .. "/", 1, true) == 1
end

---@param cwd string
---@param path string
function Tree:is_visible(cwd, path)
  assert_dir(cwd)
  if cwd == path then
    return true
  end
  local dir = vim.fs.dirname(path)
  if not self:in_cwd(cwd, path) then
    return false
  end
  local node = self:node(dir)
  while node do
    if node.path == cwd then
      return true
    elseif not node.open then
      return false
    end
    node = node.parent
  end
  return false
end

---@param cwd string
function Tree:close_all(cwd)
  self:walk(self:find(cwd), function(node)
    node.open = false
  end, { all = true })
end

---@param cwd string
---@param filter fun(node: snacks.picker.explorer.Node):boolean?
---@param opts? {up?: boolean, path?: string}
function Tree:next(cwd, filter, opts)
  opts = opts or {}
  local path = opts.path or cwd
  local root = self:node(cwd) or nil
  if not root then
    return
  end
  local first ---@type snacks.picker.explorer.Node?
  local last ---@type snacks.picker.explorer.Node?
  local prev ---@type snacks.picker.explorer.Node?
  local next ---@type snacks.picker.explorer.Node?
  local found = false
  self:walk(root, function(node)
    local want = not node.dir and filter(node) and not node.ignored
    if node.path == path then
      found = true
    end
    if want then
      first, last = first or node, node
      next = next or (found and node.path ~= path and node) or nil
      prev = not found and node or prev
    end
  end, { all = true })
  if opts.up then
    return prev or last
  end
  return next or first
end

---@param node snacks.picker.explorer.Node
---@param snapshot snacks.picker.explorer.Snapshot
function Tree:changed(node, snapshot)
  local old = snapshot.state
  local current = self:snapshot(node, snapshot.fields).state
  if vim.tbl_count(current) ~= vim.tbl_count(old) then
    return true
  end
  for n, data in pairs(current) do
    local prev = old[n]
    if not prev then
      return true
    end
    if not vim.deep_equal(prev, data) then
      return true
    end
  end
  return false
end

---@param node snacks.picker.explorer.Node
---@param fields string[]
function Tree:snapshot(node, fields)
  ---@type snacks.picker.explorer.Snapshot
  local ret = {
    state = {},
    fields = fields,
  }
  Tree:walk(node, function(n)
    local data = {} ---@type any[]
    for f, field in ipairs(fields) do
      data[f] = n[field]
    end
    ret.state[n] = data
  end, { all = true })
  return ret
end

return Tree.new()
