local M = {}

---@class snacks.picker.treesitter.Match
---@field id string
---@field name string
---@field node TSNode
---@field text string
---@field meta table<string, any>
---@field pos {[1]: number, [2]: number}
---@field end_pos {[1]: number, [2]: number}
---@field kind? string
---@field scope? "parent" | "local" | "global"
---@field children? snacks.picker.treesitter.Match[]

-- stylua: ignore
local kind_mapping = {
  constant      = "Constant",
  type          = "Class",
  enum          = "Enum",
  field         = "Field",
  ["function"]  = "Function",
  macro         = "Function",
  method        = "Method",
  namespace     = "Namespace",
  import        = "Module",
  var           = "Variable",
  -- associated = "Reference",
  -- parameter  = "Parameter",
}

local function sort(nodes)
  table.sort(nodes, function(a, b)
    if a.pos[1] ~= b.pos[1] then
      return a.pos[1] < b.pos[1]
    end
    if a.pos[2] ~= b.pos[2] then
      return a.pos[2] < b.pos[2]
    end
    if a.end_pos[1] ~= b.end_pos[1] then
      return a.end_pos[1] < b.end_pos[1]
    end
    return a.end_pos[2] < b.end_pos[2]
  end)
end

function M.get_locals(buf)
  local ok, parser = pcall(vim.treesitter.get_parser, buf)
  if not ok or not parser then
    return {}
  end
  parser:parse(true)
  local query = vim.treesitter.query.get(parser:lang(), "locals")
  if not query then
    return {}
  end

  local defs = {} ---@type snacks.picker.treesitter.Match[]
  local scopes = {} ---@type table<string,snacks.picker.treesitter.Match>
  for _, tree in ipairs(parser:trees()) do
    for id, node, meta in query:iter_captures(tree:root(), buf) do
      local name = query.captures[id]
      local range = { node:range() }
      ---@type snacks.picker.treesitter.Match
      local match = {
        id = node:id(),
        node = node,
        name = name,
        meta = meta,
        text = vim.treesitter.get_node_text(node, buf),
        pos = { range[1] + 1, range[2] },
        end_pos = { range[3] + 1, range[4] },
      }
      local kind = name:match("^local%.definition%.(.*)$")
      if kind then
        match.kind = kind
        match.scope = meta["definition.method.scope"] or "local"
        defs[#defs + 1] = match
      elseif name == "local.scope" then
        match.kind = "scope"
        scopes[match.id] = match
      end
    end
  end

  ---@param node TSNode
  local function find_scope(node)
    local n = node:parent() ---@type TSNode?
    while n do
      if scopes[n:id()] then
        return scopes[n:id()]
      end
      n = n:parent()
    end
  end

  -- put defs in their scope nodes
  for _, def in ipairs(defs) do
    local scope = find_scope(def.node)
    if scope then
      scope.children = scope.children or {}
      table.insert(scope.children, def)
    end
  end

  -- put scopes in their parents
  local ret = {} ---@type snacks.picker.treesitter.Match[]
  for _, scope in pairs(scopes) do
    local parent = find_scope(scope.node)
    if parent then
      parent.children = parent.children or {}
      table.insert(parent.children, scope)
    else
      ret[#ret + 1] = scope
    end
  end

  return ret
end

---@param opts snacks.picker.treesitter.Config
---@type snacks.picker.finder
function M.symbols(opts, ctx)
  local buf = ctx.filter.current_buf
  local tree = M.get_locals(buf)
  local items = {} ---@type snacks.picker.finder.Item[]
  local last = {} ---@type table<snacks.picker.finder.Item,snacks.picker.finder.Item>

  local filter = opts.filter[vim.bo[buf].filetype]
  if filter == nil then
    filter = opts.filter.default
  end

  ---@param kind string?
  local function want(kind)
    kind = kind or "Unknown"
    return type(filter) == "boolean" or vim.tbl_contains(filter, kind)
  end

  ---@type snacks.picker.finder.Item
  local root = { text = "root" }

  ---@param match snacks.picker.treesitter.Match
  ---@param parent snacks.picker.finder.Item?
  ---@return snacks.picker.finder.Item?
  local function add(match, parent, depth)
    local item ---@type snacks.picker.finder.Item?
    local kind = match.kind and kind_mapping[match.kind]
    if want(kind) then
      item = {
        text = match.text,
        depth = depth or 0,
        tree = opts.tree,
        buf = buf,
        name = match.text,
        kind = kind_mapping[match.kind] or "Unknown",
        ts_kind = match.kind,
        pos = match.pos,
        end_pos = match.end_pos,
        last = true,
        parent = parent,
      }
      if parent then
        if last[parent] then
          last[parent].last = false
        end
        last[parent] = item
      end
      items[#items + 1] = item
    end
    local children = match.children or {}
    sort(children)
    for _, child in ipairs(children) do
      local c = add(child, item or parent, depth + 1)
      -- first item in a scope is the scope itself
      if match.kind == "scope" and c and c.depth == depth + 1 then
        item = item or c
      end
    end
    return item
  end

  sort(tree)

  for _, scope in ipairs(tree) do
    add(scope, root, 0)
  end

  return items
end

return M
