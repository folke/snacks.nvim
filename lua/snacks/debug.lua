---@class snacks.debug
---@overload fun(...)
local M = setmetatable({}, {
  __call = function(t, ...)
    return t.inspect(...)
  end,
})

local uv = vim.uv or vim.loop

-- Show a notification with a pretty printed dump of the object(s)
-- with lua treesitter highlighting and the location of the caller
function M.inspect(...)
  local len = select("#", ...) ---@type number
  local obj = { ... } ---@type unknown[]
  local caller = debug.getinfo(1, "S")
  for level = 2, 10 do
    local info = debug.getinfo(level, "S")
    if
      info
      and info.source ~= caller.source
      and info.what == "Lua"
      and info.source ~= "lua"
      and info.source ~= "@" .. (vim.env.MYVIMRC or "")
    then
      caller = info
      break
    end
  end
  local title = "Debug: " .. vim.fn.fnamemodify(caller.source:sub(2), ":~:.") .. ":" .. caller.linedefined
  Snacks.notify.warn(vim.inspect(len == 1 and obj[1] or len > 0 and obj or nil), { title = title, ft = "lua" })
end

-- Show a notification with a pretty backtrace
function M.backtrace()
  local trace = {}
  for level = 2, 20 do
    local info = debug.getinfo(level, "Sln")
    if info and info.what == "Lua" and info.source ~= "lua" then
      local line = "- `" .. vim.fn.fnamemodify(info.source:sub(2), ":p:~:.") .. "`:" .. info.currentline
      if info.name then
        line = line .. " _in_ **" .. info.name .. "**"
      end
      table.insert(trace, line)
    end
  end
  Snacks.notify.warn(#trace > 0 and (table.concat(trace, "\n")) or "", { title = "Backtrace" })
end

-- Very simple function to profile a lua function.
-- * **flush**: set to `true` to use `jit.flush` in every iteration.
-- * **count**: defaults to 100
---@param fn fun()
---@param opts? {count?: number, flush?: boolean}
function M.profile(fn, opts)
  opts = vim.tbl_extend("force", { count = 100, flush = true }, opts or {})
  local start = uv.hrtime()
  for _ = 1, opts.count, 1 do
    if opts.flush then
      jit.flush(fn, true)
    end
    fn()
  end
  Snacks.notify(((uv.hrtime() - start) / 1e6 / opts.count) .. "ms")
end

-- Log a message to the file `./debug.log`.
-- - a timestamp will be added to every message.
-- - accepts multiple arguments and pretty prints them.
-- - if the argument is not a string, it will be printed using `vim.inspect`.
-- - if the message is smaller than 120 characters, it will be printed on a single line.
--
-- ```lua
-- Snacks.debug.log("Hello", { foo = "bar" }, 42)
-- -- 2024-11-08 08:56:52 Hello { foo = "bar" } 42
-- ```
function M.log(...)
  local file = "./debug.log"
  local fd = io.open(file, "a+")
  if not fd then
    error(("Could not open file %s for writing"):format(file))
  end
  local c = select("#", ...)
  local parts = {} ---@type string[]
  for i = 1, c do
    local v = select(i, ...)
    parts[i] = type(v) == "string" and v or vim.inspect(v)
  end
  local msg = table.concat(parts, " ")
  msg = #msg < 120 and msg:gsub("%s+", " ") or msg
  fd:write(os.date("%Y-%m-%d %H:%M:%S ") .. msg)
  fd:write("\n")
  fd:close()
end

---@alias snacks.debug.Trace {name: string, time: number, [number]:snacks.debug.Trace}
---@alias snacks.debug.Stat {name:string, time:number, count?:number, depth?:number}

---@type snacks.debug.Trace[]
M._traces = { { name = "__TOP__", time = 0 } }

---@param name string?
function M.trace(name)
  if name then
    local entry = { name = name, time = uv.hrtime() } ---@type snacks.debug.Trace
    table.insert(M._traces[#M._traces], entry)
    table.insert(M._traces, entry)
    return entry
  else
    local entry = assert(table.remove(M._traces), "trace not ended?") ---@type snacks.debug.Trace
    entry.time = uv.hrtime() - entry.time
    return entry
  end
end

---@param modname string
---@param mod? table
---@param suffix? string
function M.tracemod(modname, mod, suffix)
  mod = mod or require(modname)
  suffix = suffix or "."
  for k, v in pairs(mod) do
    if type(v) == "function" and k ~= "trace" then
      mod[k] = function(...)
        M.trace(modname .. suffix .. k)
        local ok, ret = pcall(v, ...)
        M.trace()
        return ok == false and error(ret) or ret
      end
    end
  end
end

---@param opts? {min?: number, show?:boolean}
---@return {summary:table<string, snacks.debug.Stat>, trace:snacks.debug.Stat[], traces:snacks.debug.Trace[]}
function M.stats(opts)
  opts = opts or {}
  local stack, lines, trace = {}, {}, {} ---@type string[], string[], snacks.debug.Stat[]
  local summary = {} ---@type table<string, snacks.debug.Stat>
  ---@param stat snacks.debug.Trace
  local function collect(stat)
    if #stack > 0 then
      local recursive = vim.list_contains(stack, stat.name)
      summary[stat.name] = summary[stat.name] or { time = 0, count = 0, name = stat.name }
      summary[stat.name].time = summary[stat.name].time + (recursive and 0 or stat.time)
      summary[stat.name].count = summary[stat.name].count + 1
      table.insert(trace, { name = stat.name, time = stat.time or 0, depth = #stack - 1 })
    end
    table.insert(stack, stat.name)
    for _, entry in ipairs(stat) do
      collect(entry)
    end
    table.remove(stack)
  end
  collect(M._traces[1])

  ---@param entries snacks.debug.Stat[]
  local function add(entries)
    for _, stat in ipairs(entries) do
      local ms = math.floor(stat.time / 1e4) / 1e2
      if ms >= (opts.min or 0) then
        local line = ("%s- `%s`: **%.2f**ms"):format(("  "):rep(stat.depth or 0), stat.name, ms)
        table.insert(lines, line .. (stat.count and (" ([%d])"):format(stat.count) or ""))
      end
    end
  end

  if opts.show ~= false then
    lines[#lines + 1] = "# Summary"
    summary = vim.tbl_values(summary)
    table.sort(summary, function(a, b)
      return a.time > b.time
    end)
    add(summary)
    lines[#lines + 1] = "\n# Trace"
    add(trace)
    Snacks.notify.warn(lines, { title = "Traces" })
  end
  return { summary = summary, trace = trace, tree = M._traces }
end

return M
