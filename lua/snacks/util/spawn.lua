local Async = require("snacks.picker.util.async")

---@class snacks.spawn
local M = {}

local uv = vim.uv or vim.loop

---@class snacks.spawn.Config: uv.spawn.options,{}
---@field cmd string
---@field args? (string|number)[]
---@field timeout? number
---@field run? boolean
---@field debug? boolean
---@field input? string
---@field on_stdout? fun(proc: snacks.spawn.Proc, data: string)
---@field on_stderr? fun(proc: snacks.spawn.Proc, data: string)
---@field on_exit? fun(proc: snacks.spawn.Proc, err: boolean)

---@class snacks.spawn.Multi: snacks.spawn.Config,{}
---@field cmd? nil
---@field on_exit? fun(procs: snacks.spawn.Proc[], err: boolean)

---@class snacks.spawn.Proc: snacks.picker.Waitable
---@field opts snacks.spawn.Config
---@field handle? uv.uv_process_t
---@field stdout uv.uv_pipe_t
---@field stderr uv.uv_pipe_t
---@field stdin? uv.uv_pipe_t
---@field code? number
---@field signal? number
---@field timer? uv.uv_timer_t
---@field aborted? boolean
---@field data table<uv.uv_pipe_t, string[]>
---@field async? snacks.picker.Async
---@field did_exit? boolean
local Proc = {}
Proc.__index = Proc

---@param handle uv.uv_handle_t?
local function close(handle)
  if handle and not handle:is_closing() then
    handle:close()
  end
end

---@param opts snacks.spawn.Config
function Proc.new(opts)
  local self = setmetatable({}, Proc)
  self.opts = opts
  self.code, self.signal = 0, 0
  self.data = {}
  if opts.run ~= false then
    self:run()
  end
  return self
end

function Proc:running()
  return self.handle and not self.handle:is_closing()
end

---@param signal? string|number
function Proc:kill(signal)
  close(self.stdout)
  close(self.stderr)
  if self:running() then
    self.aborted = true
    self.handle:kill(signal or "sigterm")
  end
end

function Proc:failed()
  if self.aborted then
    return true
  end
  if self:running() then
    return false
  end
  return self.code ~= 0 or self.signal ~= 0
end

---@param opts? snacks.debug.cmd|{}
function Proc:debug(opts)
  ---@type snacks.debug.cmd
  opts = Snacks.config.merge({}, opts or {}, {
    cmd = self.opts.cmd,
    args = self.opts.args,
    cwd = self.opts.cwd,
  })
  opts.props = opts.props or {}
  if not self:running() then
    opts.props.code = ("`%d`"):format(self.code)
    opts.props.signal = ("`%d`"):format(self.signal)
    if self.aborted then
      opts.props.aborted = "`true`"
    end
  end
  if self:failed() then
    opts.level = "error"
  end
  local out = vim.trim(self:out() .. "\n" .. self:err())
  if out ~= "" then
    opts.footer = "# Output\n```\n" .. out .. "\n```"
  end
  return Snacks.debug.cmd(opts)
end

function Proc:setup_async()
  self.async = Async.running()
  if self.async then
    self.async:on("abort", function()
      if self:running() then
        self:kill()
      end
    end)
  end
end

---@async
function Proc:wait()
  self:setup_async()
  assert(self.async, "Not in an async context")
  assert(self.async == Async.running(), "Not in the current async context")
  while not self.did_exit or self:running() do
    self.async:suspend()
  end
  return self
end

function Proc:run()
  assert(not self.handle, "already running")
  if self.aborted then
    return self:on_exit()
  end

  self:setup_async()

  self.stdout = assert(uv.new_pipe())
  self.stderr = assert(uv.new_pipe())
  self.stdin = self.opts.input and assert(uv.new_pipe()) or nil
  self.data = { [self.stdout] = {}, [self.stderr] = {} }
  if self.opts.debug then
    vim.schedule(function()
      self:debug()
    end)
  end
  local opts = vim.tbl_deep_extend("force", self.opts, {
    stdio = { self.stdin, self.stdout, self.stderr },
    hide = true,
    args = vim.tbl_map(tostring, self.opts.args or {}),
  })
  self.handle = uv.spawn(self.opts.cmd, opts, function(code, signal)
    self.code = code
    self.signal = signal
    self:on_exit()
  end)
  if not self.handle then
    self.code = 1
    self.data[self.stderr] = { "Failed to spawn " .. self.opts.cmd }
    close(self.stdout)
    close(self.stderr)
    return self:on_exit()
  end

  if self.stdin and self.opts.input then
    self.stdin:write(self.opts.input)
    self.stdin:shutdown()
    self.stdin:close()
  end

  if self.opts.timeout then
    self.timer = assert(uv.new_timer())
    self.timer:start(self.opts.timeout, 0, function()
      self:kill("sigterm")
    end)
  end
  for _, handle in ipairs({ self.stdout, self.stderr }) do
    handle:read_start(function(err, data)
      assert(not err, err)
      if data then
        self:on_data(data, handle)
      else
        close(handle)
      end
    end)
  end
end

function Proc:json()
  return vim.json.decode(self:out())
end

function Proc:out()
  return table.concat(self.data[self.stdout] or {})
end

function Proc:err()
  return table.concat(self.data[self.stderr] or {})
end

function Proc:lines()
  return vim.split(self:out(), "\n", { plain = true })
end

---@param data string
---@param handle uv.uv_pipe_t
function Proc:on_data(data, handle)
  table.insert(self.data[handle], data)
  if self.opts.on_stdout and handle == self.stdout then
    self.opts.on_stdout(self, data)
  elseif self.opts.on_stderr and handle == self.stderr then
    self.opts.on_stderr(self, data)
  end
end

function Proc:on_exit()
  close(self.timer)
  close(self.handle)
  local check = assert(uv.new_check())
  check:start(function()
    for _, handle in ipairs({ self.stdout, self.stderr }) do
      if handle and not handle:is_closing() then
        return
      end
    end
    check:stop()
    close(check)
    close(self.stdout)
    close(self.stderr)
    if self.opts.on_exit then
      self.opts.on_exit(self, self.code ~= 0 or self.signal ~= 0 or self.aborted or false)
    end
    self.did_exit = true
    if self.async then
      self.async:resume()
    end
  end)
end

---@param procs snacks.spawn.Proc[]
---@param opts? snacks.spawn.Multi
function M.multi(procs, opts)
  if #procs == 0 then
    return
  end
  opts = opts or {}
  local current = 0

  local function done()
    if opts.on_exit then
      opts.on_exit(procs, procs[current]:failed())
    end
  end

  local function next()
    current = current + 1
    assert(current <= #procs, "current > #procs")
    local proc = procs[current]
    proc.opts = Snacks.config.merge(vim.deepcopy(opts), proc.opts, {
      on_exit = function(_, err)
        if err or current == #procs then
          done()
        else
          next()
        end
      end,
    })
    proc:run()
  end

  ---@type snacks.spawn.Proc|{procs: snacks.spawn.Proc[]}
  local ret = setmetatable({
    procs = procs,
    run = next,
  }, {
    __index = function(_, k)
      return procs[current][k]
    end,
  })

  if opts.run ~= false then
    next()
  end
  return ret
end

M.new = Proc.new

---@param cmd string[]
---@async
function M.exec(cmd)
  return vim.trim(M.new({
    cmd = cmd[1],
    args = vim.list_slice(cmd, 2),
    stdout_buffered = true,
    stderr_buffered = true,
  })
    :wait()
    :out())
end

return M
