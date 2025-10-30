---@class snacks.debug
---@overload fun(...)
local M = setmetatable({}, {
  __call = function(t, ...)
    return t.inspect(...)
  end,
})

M.meta = {
  desc = "Pretty inspect & backtraces for debugging",
}

---@class snacks.debug.cmd
---@field cmd string|string[]
---@field level? snacks.notifier.level|vim.log.levels
---@field title? string
---@field args? string[]
---@field cwd? string
---@field group? boolean
---@field notify? boolean
---@field footer? string
---@field header? string
---@field props? table<string, string|boolean|number|nil>

local uv = vim.uv or vim.loop

local MAX_INSPECT_LINES = 2000

vim.schedule(function()
  Snacks.util.set_hl({
    Indent = "LineNr",
    Print = "NonText",
  }, { prefix = "SnacksDebug", default = true })
end)

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
      and info.what ~= "C"
      and info.source ~= "lua"
      and info.source ~= "@" .. (os.getenv("MYVIMRC") or "")
    then
      caller = info
      break
    end
  end
  vim.schedule(function()
    local title = "Debug: " .. vim.fn.fnamemodify(caller.source:sub(2), ":~:.") .. ":" .. caller.linedefined
    local lines = vim.split(vim.inspect(len == 1 and obj[1] or len > 0 and obj or nil), "\n")
    if #lines > MAX_INSPECT_LINES then
      local c = #lines
      lines = vim.list_slice(lines, 1, MAX_INSPECT_LINES)
      lines[#lines + 1] = ""
      lines[#lines + 1] = (c - MAX_INSPECT_LINES) .. " more lines have been truncated …"
    end
    Snacks.notify.warn(lines, { title = title, ft = "lua" })
  end)
end

--- Run the current buffer or a range of lines.
--- Shows the output of `print` inlined with the code.
--- Any error will be shown as a diagnostic.
---@param opts? {name?:string, buf?:number, print?:boolean}
function M.run(opts)
  local ns = vim.api.nvim_create_namespace("snacks_debug")
  opts = vim.tbl_extend("force", { print = true }, opts or {})
  local buf = opts.buf or 0
  buf = buf == 0 and vim.api.nvim_get_current_buf() or buf
  local name = opts.name or vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")

  -- Get the lines to run
  local lines ---@type string[]
  local mode = vim.fn.mode()
  if mode:find("[vV]") then
    if mode == "v" then
      vim.cmd("normal! v")
    elseif mode == "V" then
      vim.cmd("normal! V")
    end
    local from = vim.api.nvim_buf_get_mark(buf, "<")
    local to = vim.api.nvim_buf_get_mark(buf, ">")

    -- for some reason, sometimes the column is off by one
    -- see: https://github.com/folke/snacks.nvim/issues/190
    local col_to = math.min(to[2] + 1, #vim.api.nvim_buf_get_lines(buf, to[1] - 1, to[1], false)[1])

    lines = vim.api.nvim_buf_get_text(buf, from[1] - 1, from[2], to[1] - 1, col_to, {})
    -- Insert empty lines to keep the line numbers
    for _ = 1, from[1] - 1 do
      table.insert(lines, 1, "")
    end
    vim.fn.feedkeys("gv", "nx")
  elseif mode == "\22" then
    -- Yank the visual selection to handle irregularly shaped blocks
    local tmp = vim.fn.getreginfo("*")
    vim.cmd('normal! "*y')
    lines = vim.fn.getreginfo("*").regcontents
    vim.fn.setreg("*", tmp.regcontents, tmp.regtype)

    -- Insert empty lines to keep the line numbers
    local from = vim.api.nvim_buf_get_mark(buf, "<")
    for _ = 1, from[1] - 1 do
      table.insert(lines, 1, "")
    end

    -- Restore the selection
    vim.fn.feedkeys("gv", "nx")
  else
    lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  end

  -- Clear diagnostics and extmarks
  local function reset()
    vim.diagnostic.reset(ns, buf)
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  end
  reset()
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = vim.api.nvim_create_augroup("snacks_debug_run_" .. buf, { clear = true }),
    buffer = buf,
    callback = reset,
  })

  -- Get the line number from the msg or stack
  local function get_line(msg)
    local line = msg and msg:match("^" .. vim.pesc(name) .. ":(%d+):")
    if line then
      return line
    end
    for level = 2, 20 do
      local info = debug.getinfo(level, "Sln")
      if info and info.source == "@" .. name then
        return info.currentline
      end
    end
  end

  -- Error handler
  local function on_error(err)
    local line = get_line(err)
    if line then
      vim.diagnostic.set(ns, buf, {
        { col = 0, lnum = line - 1, message = err, severity = vim.diagnostic.severity.ERROR },
      })
    end
    M.backtrace({ err, "" }, { title = "Error in " .. name, level = vim.log.levels.ERROR })
  end

  -- Print handler
  local function on_print(...)
    local str = table.concat(
      vim.tbl_map(function(v)
        return type(v) == "string" and v or vim.inspect(v)
      end, { ... }),
      " "
    )
    ---@type string[][][]
    local virt_lines = {}
    for _, line in ipairs(vim.split(str, "\n", { plain = true })) do
      table.insert(virt_lines, { { "  │ ", "SnacksDebugIndent" }, { line, "SnacksDebugPrint" } })
    end

    local line = (get_line() or 1) - 1
    vim.schedule(function()
      vim.api.nvim_buf_set_extmark(buf, ns, line, 0, {
        virt_lines = virt_lines,
      })
    end)
  end

  -- Load the code
  local chunk, err = load(table.concat(lines, "\n"), "@" .. name)
  if not chunk then
    return on_error(err)
  end

  -- Setup the env
  local env = { print = opts.print and on_print or nil }
  package.seeall(env)
  setfenv(chunk, env)
  xpcall(chunk, function(e)
    on_error(e)
  end)
end

-- Show a notification with a pretty backtrace
---@param msg? string|string[]
---@param opts? snacks.notify.Opts
function M.backtrace(msg, opts)
  opts = vim.tbl_deep_extend("force", {
    level = vim.log.levels.WARN,
    title = "Backtrace",
  }, opts or {})
  ---@type string[]
  local trace = type(msg) == "table" and msg or type(msg) == "string" and { msg } or {}
  for level = 2, 20 do
    local info = debug.getinfo(level, "Sln")
    if info and info.what ~= "C" and info.source ~= "lua" and not info.source:find("snacks[/\\]debug") then
      local line = "- `" .. vim.fn.fnamemodify(info.source:sub(2), ":p:~:.") .. "`:" .. info.currentline
      if info.name then
        line = line .. " _in_ **" .. info.name .. "**"
      end
      table.insert(trace, line)
    end
  end
  Snacks.notify(#trace > 0 and (table.concat(trace, "\n")) or "", opts)
end

-- Very simple function to profile a lua function.
-- * **flush**: set to `true` to use `jit.flush` in every iteration.
-- * **count**: defaults to 100
---@param fn fun()
---@param opts? {count?: number, flush?: boolean, title?: string}
function M.profile(fn, opts)
  opts = vim.tbl_extend("force", { count = 100, flush = true }, opts or {})
  local start = uv.hrtime()
  for _ = 1, opts.count, 1 do
    if opts.flush then
      jit.flush(fn, true)
    end
    fn()
  end
  Snacks.notify(((uv.hrtime() - start) / 1e6 / opts.count) .. "ms", { title = opts.title or "Profile" })
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

function M.size(bytes)
  local sizes = { "B", "KB", "MB", "GB", "TB" }
  local s = 1
  while bytes > 1024 and s < #sizes do
    bytes = bytes / 1024
    s = s + 1
  end
  return ("%.2f%s"):format(bytes, sizes[s])
end

function M.metrics()
  collectgarbage("collect")
  local lines = {} ---@type string[]
  local function add(name, value)
    lines[#lines + 1] = ("- **%s**: %s"):format(name, value)
  end

  add("lua", M.size(collectgarbage("count") * 1024))

  for _, stat in ipairs({ "get_total_memory", "get_free_memory", "get_available_memory", "resident_set_memory" }) do
    add(stat:gsub("get_", ""):gsub("_", " "), M.size(uv[stat]()))
  end
  lines[#lines + 1] = ("```lua\n%s\n```"):format(vim.inspect(uv.getrusage()))
  Snacks.notify.warn(lines, { title = "Metrics" })
end

---@param opts snacks.debug.cmd
function M.cmd(opts)
  local cmd = opts.cmd
  local args = vim.deepcopy(opts.args or {})
  if type(cmd) == "table" then
    vim.list_extend(args, cmd, 2)
    cmd = cmd[1]
  end
  args = vim.tbl_map(tostring, args)
  ---@cast cmd string
  local lines = { cmd } ---@type string[]
  for _, arg in ipairs(args or {}) do
    arg = arg:find("[%$%s%?]") and vim.fn.shellescape(arg) or arg
    if #arg + #lines[#lines] > 40 then
      lines[#lines] = lines[#lines] .. " \\"
      table.insert(lines, "  " .. arg)
    else
      lines[#lines] = lines[#lines] .. " " .. arg
    end
  end
  local props = vim.deepcopy(opts.props or {})
  props.cwd = props.cwd or vim.fn.fnamemodify(opts.cwd or uv.cwd() or ".", ":~")
  local prop_keys = vim.tbl_keys(props) ---@type string[]
  table.sort(prop_keys)
  local prop_lines = {} ---@type string[]
  for _, key in ipairs(prop_keys) do
    table.insert(prop_lines, ("- **%s**: %s"):format(key, props[key]))
  end

  local id = cmd or "cmd"
  lines = {
    opts.header or "",
    table.concat(prop_lines, "\n"),
    "```sh",
    table.concat(lines, " \n"),
    "```",
    opts.footer or "",
  }
  if opts.title and not opts.notify then
    table.insert(lines, 1, ("# %s\n"):format(opts.title))
  end
  local msg = vim.trim(table.concat(lines, "\n")):gsub("\n\n+", "\n\n")
  if opts.notify ~= false then
    Snacks.notify(msg, {
      id = opts.group and ("snacks.debug.cmd." .. id) or nil,
      level = opts.level or vim.log.levels.INFO,
      title = opts.title or "Cmd Debug",
    })
  end
  return msg
end

return M
