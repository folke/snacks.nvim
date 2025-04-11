---@alias snacks.profiler.Trace.opts snacks.profiler.Trace|{id?:number, pid?:number, time?:number, depth?:number}
---@alias snacks.profiler.Event {id:number, pid:number, start:number, stop:number, measurements:number, ref?:snacks.profiler.Loc, idx:number, opts:snacks.profiler.Trace.opts}
---@alias snacks.profiler.Node {group:string, trace:snacks.profiler.Trace, children:table<string|number,snacks.profiler.Node>, order:(string|number)[]}

---@class snacks.profiler.tracer
local M = {}

M.root = {} ---@type snacks.profiler.Trace[]

function M.load()
  M.root = {}
  local traces = {} ---@type snacks.profiler.Trace[]
  for _, event in ipairs(Snacks.profiler.core.events) do
    local trace = setmetatable({}, { __index = event.opts })
    trace.id = event.id
    trace.pid = event.pid
    trace.ref = event.ref
    trace.depth = 0
    if event.stop then
      trace.time = event.stop - event.start
      traces[event.id] = trace
      if traces[event.pid] then
        trace.depth = traces[event.pid].depth + 1
        table.insert(traces[event.pid], trace)
      elseif trace.time then
        table.insert(M.root, trace)
      end
    end
  end
end

---@param on_start? fun(entry:snacks.profiler.Trace):any?
---@param on_end? fun(entry:snacks.profiler.Trace, start?:any)
function M.walk(on_start, on_end)
  ---@param entry snacks.profiler.Trace
  local function walk(entry)
    local start = on_start and on_start(entry)
    for _, child in ipairs(entry) do
      walk(child)
    end
    if on_end then
      on_end(entry, start)
    end
  end
  for _, child in ipairs(M.root) do
    walk(child)
  end
end

---@param fn snacks.profiler.GroupFn
---@param opts? {structure?:boolean, sort?:"time"|"count"}
function M.group(fn, opts)
  opts = opts or {}
  ---@type snacks.profiler.Node[]
  local nodes = { { children = {}, order = {} } } -- root node

  ---@param entry snacks.profiler.Trace
  M.walk(function(entry)
    local group = fn(entry)
    if group then
      local key, parent, recursive = group.key, nodes[1], false
      for n = 2, #nodes do
        local node = nodes[n]
        if node.group == key then
          recursive = true
          break
        end
        parent = opts.structure and node or parent
      end
      local node = parent.children[key]
      if not node then
        local trace = vim.tbl_extend("force", { time = 0, count = 0, name = key, depth = #nodes - 1 }, group)
        node = { group = key, trace = trace, children = {}, order = {} } ---@type snacks.profiler.Node
        ---@diagnostic disable-next-line: no-unknown
        parent.children[key] = node
        table.insert(parent.order, key)
      end
      if not recursive then
        table.insert(nodes, node)
        node.trace.time = node.trace.time + entry.time
      end
      node.trace.count = node.trace.count + 1
      table.insert(node.trace, entry)
      return not recursive
    end
  end, function(_, start)
    if start then
      table.remove(nodes)
    end
  end)

  assert(#nodes == 1, "node stack not empty")
  return nodes[1]
end

---@param node snacks.profiler.Node
---@param opts? snacks.profiler.Find
function M.flatten(node, opts)
  opts = opts or {}
  local ret = {} ---@type snacks.profiler.Trace[]
  ---@param n snacks.profiler.Node
  local function walk(n)
    if n.trace and (n.trace.time / 1e6 >= (opts.min_time or 0)) then
      table.insert(ret, n.trace)
    end
    if opts.sort then
      local children = vim.tbl_values(n.children) ---@type snacks.profiler.Node[]
      if opts.sort == "time" then
        table.sort(children, function(a, b)
          return a.trace.time > b.trace.time
        end)
      elseif opts.sort == "count" then
        table.sort(children, function(a, b)
          return a.trace.count > b.trace.count
        end)
      end
      for _, child in ipairs(children) do
        walk(child)
      end
    else
      for _, key in ipairs(n.order) do
        walk(n.children[key])
      end
    end
  end
  walk(node)
  return ret
end

---@param opts snacks.profiler.Find
function M.find(opts)
  opts = opts or {}
  opts = vim.tbl_extend("force", {
    group = "name",
    structure = opts.group ~= false,
    sort = (opts.group ~= false) and "time",
  }, opts or {})
  opts.group = opts.group == true and "name" or opts.group
  opts.sort = opts.sort == true and "time" or opts.sort
  ---@cast opts snacks.profiler.Find
  local key_parts = {} ---@type table<string, string[]>
  local id = 0

  ---@param entry snacks.profiler.Trace
  ---@param key string|false
  local function get(entry, key)
    if key == false then
      id = id + 1
      return tostring(id), entry.name
    end
    local parts = key_parts[key]
    if not parts then
      parts = vim.split(key, "[_%.]")
      if #parts == 1 and (parts[1] == "ref" or parts[1] == "def") then
        parts[2] = "loc"
      end
      key_parts[key] = parts
    end
    local value = vim.tbl_get(entry, unpack(parts)) ---@type string?
    if not value then
      return
    end
    local name, loc = value, entry.def
    if parts[1] == "ref" or parts[1] == "require" then
      loc = entry.ref
    elseif parts[1] == "name" and entry.require then
      loc = entry.ref
    end
    if parts[2] == "def" or parts[1] == "name" then
      name = entry.name
    else
      name = parts[#parts] .. ":" .. value
    end
    return value, name, loc
  end

  -- Build the filter
  local filter = {} ---@type table<string, string|boolean>
  local current ---@type snacks.profiler.Trace?
  for k, v in pairs(opts.filter or {}) do
    if v == true then
      -- If the value is true, then we want the current location
      if k:find("[rd]ef") then
        if not current then
          local loc = Snacks.profiler.loc.current()
          ---@diagnostic disable-next-line: missing-fields
          current = { def = loc, ref = loc }
        end
        v = get(current, k) or false
      else -- match all
        v = "^.*$"
      end
    end
    filter[k] = v
  end

  ---@param entry snacks.profiler.Trace
  local function match(entry)
    for key, m in pairs(filter) do
      local value = get(entry, key) or false
      if type(m) == "string" and m:sub(1, 1) == "^" then
        if not (value and value:find(m)) then
          return false
        end
      elseif value ~= m then
        return false
      end
    end
    return true
  end

  ---@type snacks.profiler.GroupFn
  local group_fn = function(entry)
    if opts.filter and not match(entry) then
      return
    end
    local key, name, loc = get(entry, opts.group --[[@as string|false]])
    if key then
      loc = opts.loc and entry[opts.loc] or loc or entry.def or entry.ref
      return { key = key, name = name, loc = loc, ref = entry.ref, def = entry.def }
    end
  end

  local node = M.group(group_fn, opts)
  return M.flatten(node, opts), node, opts
end

return M
