---@class snacks.profiler.core
local M = {}

local hrtime = (vim.uv or vim.loop).hrtime
local nvim_create_autocmd = vim.api.nvim_create_autocmd

M._require = _G.require
M.attached = {} ---@type table<unknown, boolean>
M.events = {} ---@type snacks.profiler.Event[]
M.filter_fn = error ---@type fun(str:string):boolean
M.filter_mod = error ---@type fun(str:string):boolean
M.id = 0
M.me = debug.getinfo(1, "S").source:sub(2)
M.pids = {} ---@type table<string, number>
M.running = false
M.skips = { -- these modules are always be skipped
  ["_G"] = true,
  ["bit"] = true,
  ["coroutine"] = true,
  ["debug"] = true,
  ["ffi"] = true,
  ["io"] = true,
  ["jit"] = true,
  ["jit.opt"] = true,
  ["jit.profile"] = true,
  ["lpeg"] = true,
  ["luv"] = true,
  ["math"] = true,
  ["mpack"] = true,
  ["os"] = true,
  ["package"] = true,
  ["snacks.debug"] = true,
  ["snacks.profiler"] = true,
  ["snacks.profiler.core"] = true,
  ["snacks.profiler.loc"] = true,
  ["snacks.profiler.picker"] = true,
  ["snacks.profiler.tracer"] = true,
  ["snacks.profiler.ui"] = true,
  ["string"] = true,
  ["table"] = true,
}

function M.skip(it)
  M.attached[it] = true
end

---@param spec table<string, boolean>
---@return fun(str:string):boolean
function M.filter(spec)
  local filters = {} ---@type {pattern:string, want:boolean, exact:boolean}[]
  local default = spec.default
  default = default == nil and true or default
  for pattern, want in pairs(spec) do
    if pattern ~= "default" then
      table.insert(filters, { pattern = pattern, want = want, exact = pattern:sub(1, 1) ~= "^" })
    end
  end
  -- sort by longest pattern first
  table.sort(filters, function(a, b)
    return #a.pattern > #b.pattern
  end)
  return function(str)
    for _, filter in ipairs(filters) do
      if filter.exact then
        if str == filter.pattern then
          return filter.want
        end
      elseif str:find(filter.pattern) then
        return filter.want
      end
    end
    return default
  end
end

---@param opts snacks.profiler.Trace.opts
---@param caller? snacks.profiler.Loc
---@return ...
function M.trace(opts, caller, ...)
  local start = hrtime()
  local thread = tostring(coroutine.running() or "main")
  local pid = M.pids[thread] or 0
  M.id = M.id + 1
  M.pids[thread] = M.id
  ---@type snacks.profiler.Event
  local entry = { id = M.id, start = start, pid = pid, ref = caller, opts = opts }
  M.events[#M.events + 1] = entry
  local ret = { pcall(opts.fn, ...) }
  M.pids[thread] = pid
  entry.stop = hrtime()
  if not ret[1] then
    error(ret[2])
  end
  return select(2, unpack(ret))
end

---@param depth? number
---@param max_depth? number
---@return snacks.profiler.Loc?
function M.caller(depth, max_depth)
  for i = depth or 3, max_depth or 10 do
    local info = debug.getinfo(i, "Sl")
    if not info then
      return
    end
    local source = info.source:sub(2)
    if info.what ~= "C" and source ~= M.me then
      return { file = source, line = info.currentline }
    end
  end
end

---@param opts snacks.profiler.Trace.opts
function M.attach_fn(opts)
  if M.attached[opts.fn] then
    return opts.fn
  end
  M.attached[opts.fn] = true
  local ret = function(...)
    if not M.running then
      return opts.fn(...)
    end
    return M.trace(opts, M.caller() or nil, ...)
  end
  M.attached[ret] = true
  return ret
end

---@param modname string
---@param mod table<string, function>
---@param opts? {force?:boolean}
function M.attach_mod(modname, mod, opts)
  if type(mod) ~= "table" or M.attached[mod] then
    return
  end
  opts = opts or {}
  if (M.skips[modname] or not M.filter_mod(modname)) and opts.force ~= true then
    return
  end
  M.attached[mod] = true
  for k, v in pairs(mod) do
    if type(k) == "string" and type(v) == "function" and not M.attached[v] then
      local name = modname .. "." .. k
      if M.filter_fn(name) then
        mod[k] = M.attach_fn({ modname = modname, fname = k, name = name, fn = v })
      end
    end
  end
end

function M.require(modname)
  if not M.running or package.loaded[modname] or M.skips[modname] then
    return M._require(modname)
  end
  local ret = {
    M.trace({
      fname = "require",
      name = "require:" .. modname,
      require = modname,
      fn = M._require,
    }, M.caller(), modname),
  }
  if type(ret[1]) == "table" then
    M.attach_mod(modname, ret[1])
  end
  return unpack(ret)
end

---@param event any (string|array) Event(s) that will trigger the handler (`callback` or `command`).
---@param opts vim.api.keyset.create_autocmd Options dict:
function M.autocmd(event, opts)
  if opts and type(opts.callback) == "function" then
    local name = { type(event) == "string" and event or table.concat(event, "|") }
    if opts.pattern then
      name[#name + 1] = type(opts.pattern) == "string" and opts.pattern or table.concat(opts.pattern, "|")
    end
    local autocmd = table.concat(name, ":")
    local trace = { name = "autocmd:" .. autocmd, fn = opts.callback, autocmd = autocmd }
    opts.callback = function(...)
      if not M.running then
        return trace.fn(...)
      end
      return M.trace(trace, M.caller(), ...)
    end
  end
  return nvim_create_autocmd(event, opts)
end

---@param opts snacks.profiler.Config
function M.start(opts)
  assert(not M.running, "Profiler is already enabled")

  -- Clear events
  M.events = {}

  -- Setup filters and include globals
  local filter_mod = vim.deepcopy(opts.filter_mod)
  for _, global in ipairs(opts.globals) do
    filter_mod[global] = true
  end
  M.filter_mod = M.filter(filter_mod)
  M.filter_fn = M.filter(opts.filter_fn)

  -- Attach to require
  _G.require = M.require

  -- Attach to autocmds
  if opts.autocmds then
    vim.api.nvim_create_autocmd = M.autocmd
  end

  -- Attach to globals
  for _, name in ipairs(opts.globals) do
    M.attach_mod(name, vim.tbl_get(_G, unpack(vim.split(name, ".", { plain = true }))))
  end

  -- Attach to loaded modules
  ---@diagnostic disable-next-line: no-unknown
  for modname, mod in pairs(package.loaded) do
    M.attach_mod(modname, mod)
  end

  -- Enable the profiler
  M.running = true
  vim.api.nvim_exec_autocmds("User", { pattern = "SnacksProfilerStarted", modeline = false })
end

function M.stop()
  assert(M.running, "Profiler is not enabled")
  _G.require = M._require
  vim.api.nvim_create_autocmd = nvim_create_autocmd
  M.running = false
  vim.api.nvim_exec_autocmds("User", { pattern = "SnacksProfilerStopped", modeline = false })
end

return M
