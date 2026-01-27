---@class snacks.picker.async
local M = {}

---@type snacks.picker.Async[]
M._active = {}
---@type snacks.picker.Async[]
M._suspended = {}
M._executor = assert((vim.uv or vim.loop).new_check())

M.BUDGET = 10

---@type table<thread, snacks.picker.Async>
M._threads = setmetatable({}, { __mode = "k" })

local uv = (vim.uv or vim.loop)

function M.exiting()
  return vim.v.exiting ~= vim.NIL
end

---@alias snacks.picker.AsyncEvent "done" | "error" | "yield" | "ok" | "abort"

---@class snacks.picker.Waitable
---@field wait async fun()

---@class snacks.picker.Async
---@field _co? thread
---@field _fn fun()
---@field _suspended? boolean
---@field _aborted? boolean
---@field _start number
---@field _on table<snacks.picker.AsyncEvent, fun(res:any, async:snacks.picker.Async)[]>
local Async = {}
Async.__index = Async

---@param fn async fun()
---
function Async.new(fn)
  local self = setmetatable({}, Async)
  return self:init(fn)
end

---@param fn async fun()
---@return snacks.picker.Async
function Async:init(fn)
  self._fn = fn
  self._on = {}
  self._start = uv.hrtime()
  self._co = coroutine.create(function()
    local ok, err = xpcall(self._fn, function(err)
      return debug.traceback(err, 2)
    end)
    if not ok then
      if self._aborted then
        self:_emit("abort")
      else
        self:_error(err)
      end
    end
    self:_done()
  end)
  M._threads[self._co] = self
  return M.add(self)
end

function Async:aborted()
  return self._aborted
end

function Async:_done()
  if self._co == nil then
    return
  end
  self:_emit("done")
  self._fn = nil
  M._threads[self._co] = nil
  self._co = nil
  self._on = {}
end

function Async:delta()
  return (uv.hrtime() - self._start) / 1e6
end

---@param event snacks.picker.AsyncEvent
---@param cb async fun(res:any, async:snacks.picker.Async)
function Async:on(event, cb)
  if event == "done" and not self:running() then
    cb(nil, self)
    return self
  end
  self._on[event] = self._on[event] or {}
  table.insert(self._on[event], cb)
  return self
end

---@private
---@param event snacks.picker.AsyncEvent
---@param res any
function Async:_emit(event, res)
  for _, cb in ipairs(self._on[event] or {}) do
    cb(res, self)
  end
end

function Async:_error(err)
  if vim.tbl_isempty(self._on.error or {}) then
    Snacks.notify.error("Unhandled async error:\n" .. err)
  end
  self:_emit("error", err)
end

function Async:running()
  return self._co and coroutine.status(self._co) ~= "dead" and not self._aborted
end

---@async
function Async:sleep(ms)
  self:defer(ms, function() end)
end

--- Suspends the current async context.
--- Runs `fn` on the main thread and resumes the async context,
--- returning the result of `fn` or raising an error if `fn` errors.
---@generic T: any?
---@param fn fun(): T?
---@async
---@return T
function Async:schedule(fn)
  self:assert()
  local ret ---@type {[1]: boolean, [number]:any}
  vim.schedule(function()
    ret = { pcall(fn) }
    self:resume()
  end)
  self:suspend()
  if not ret[1] then
    error(ret[2])
  end
  return select(2, unpack(ret))
end

function Async:assert()
  assert(coroutine.running() == self._co, "Not in an async context")
end

--- Same as schedule, but defers the execution by `ms` milliseconds.
---@generic T: any
---@param fn fun(): T?
---@param ms number
---@async
---@return T
function Async:defer(ms, fn)
  self:assert()
  local ret ---@type {[1]: boolean, [number]:any}
  vim.defer_fn(function()
    ret = { pcall(fn) }
    self:resume()
  end, ms)
  self:suspend()
  if not ret[1] then
    error(ret[2])
  end
  return select(2, unpack(ret))
end

---@async
---@param yield? boolean
function Async:suspend(yield)
  self._suspended = true
  if coroutine.running() == self._co and yield ~= false then
    M.yield()
  end
end

function Async:resume()
  if not self._suspended then
    return
  end
  self._suspended = false
  M._run()
end

---@async
---@param yield? boolean
function Async:wake(yield)
  local async = M.running()
  assert(async, "Not in an async context")
  self:on("done", function()
    async:resume()
  end)
  async:suspend(yield)
end

---@async
function Async:wait()
  if not self:running() then
    return self
  end
  if coroutine.running() == self._co then
    error("Cannot wait on self")
  end

  local async = M.running()
  if async then
    self:wake()
  else
    while self:running() do
      vim.wait(10)
    end
  end
  return self
end

function Async:step()
  if self._suspended then
    return true
  end
  if not self._co then
    return false
  end
  local status = coroutine.status(self._co)
  if status == "suspended" then
    local ok, res = coroutine.resume(self._co, self._aborted and "abort" or nil)
    if not ok then
      error(res)
    elseif res then
      self:_emit("yield", res)
    end
  end
  return self:running()
end

function Async:abort()
  if not self:running() then
    return
  end
  self._aborted = true
  if self._co and coroutine.running() == self._co then
    error("aborted", 2)
  end
  self:resume()
end

function M.abort()
  for _, async in ipairs(M._active) do
    async:abort()
  end
end

---@async
function M.yield()
  if coroutine.yield() == "abort" then
    error("aborted", 2)
  end
end

function M.step()
  local start = uv.hrtime()
  for _ = 1, #M._active do
    if M.exiting() or uv.hrtime() - start > M.BUDGET * 1e6 then
      break
    end

    local state = table.remove(M._active, 1) ---@type snacks.picker.Async
    if state:step() then
      if state._suspended then
        table.insert(M._suspended, state)
      else
        table.insert(M._active, state)
      end
    end
  end
  for _ = 1, #M._suspended do
    local state = table.remove(M._suspended, 1)
    table.insert(state._suspended and M._suspended or M._active, state)
  end

  -- M.debug()
  if #M._active == 0 or M.exiting() then
    return M._executor:stop()
  end
end

function M.debug()
  local lines = {
    "- active: " .. #M._active,
    "- suspended: " .. #M._suspended,
  }
  for _, async in ipairs(M._active) do
    local info = debug.getinfo(async._fn)
    local file = vim.fn.fnamemodify(info.short_src:sub(1), ":~:.")
    table.insert(lines, ("%s:%d"):format(file, info.linedefined))
    if #lines > 10 then
      break
    end
  end
  local msg = table.concat(lines, "\n")
  M._notif = vim.notify(msg, nil, { replace = M._notif })
end

---@param async snacks.picker.Async
function M.add(async)
  table.insert(M._active, async)
  M._run()
  return async
end

---@async
function M.suspend()
  local async = assert(M.running(), "Not in an async context")
  async:suspend()
end

function M._run()
  if not M.exiting() and not M._executor:is_active() then
    -- M._executor:start(vim.schedule_wrap(M.step))
    M._executor:start(M.step)
  end
end

function M.running()
  local co = coroutine.running()
  if co then
    return M._threads[co]
  end
end

---@async
---@param ms number
function M.sleep(ms)
  local async = M.running()
  assert(async, "Not in an async context")
  async:sleep(ms)
end

---@param ms? number
function M.yielder(ms)
  if not coroutine.running() then
    return function() end
  end
  local ns, count, start = (ms or 5) * 1e6, 0, uv.hrtime()
  ---@async
  return function()
    count = count + 1
    if count % 100 == 0 then
      if uv.hrtime() - start > ns then
        M.yield()
        start = uv.hrtime()
      end
    end
  end
end

local nop ---@type snacks.picker.Async
--- Returns a no-op async function
function M.nop()
  if not nop then
    nop = Async.new(function() end)
    nop:step()
    M._active = vim.tbl_filter(function(a)
      return a ~= nop
    end, M._active)
  end
  return nop
end

M.Async = Async
M.new = Async.new

return M
