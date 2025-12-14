---@class vim.fn.jobstart.Opts
---@field clear_env? boolean
---@field cwd? string
---@field detach? boolean
---@field env? table<string, string>
---@field height? number
---@field on_exit? fun(job_id: number, exit_code: number, event_type: string)
---@field on_stdout? fun(job_id: number, data: string[], event_type: string)
---@field on_stderr? fun(job_id: number, data: string[], event_type: string)
---@field overlapped? boolean
---@field pty? boolean
---@field rpc? boolean
---@field stderr_buffered? boolean
---@field stdin? "pipe" | "null"
---@field stdout_buffered? boolean
---@field term? boolean
---@field width? number
---@field sync? boolean

---@class snacks.job.Opts: vim.fn.jobstart.Opts
---@field input? string
---@field output? string
---@field debug? boolean
---@field ansi? boolean
---@field start? boolean
---@field on_line? fun(job_id: number, text: string, line: number)
---@field on_lines? fun(job_id: number, lines: string[])

local M = {}

---@param opts snacks.job.Opts|vim.fn.jobstart.Opts
---@return vim.fn.jobstart.Opts
local function get_opts(opts)
  opts = vim.deepcopy(opts)
  opts.input = nil
  if opts.term == false then
    opts.term = nil
  end
  return vim.tbl_isempty(opts) and vim.empty_dict() or opts
end

---@generic F: function
---@param fn F
---@param orig? F
---@return F
local function wrap(fn, orig)
  return function(...)
    fn(...)
    if orig then
      orig(...)
    end
  end
end

---@param cmd string | string[]
---@param opts? vim.fn.jobstart.Opts
local function jobstart(cmd, opts)
  opts = opts or {}
  if opts.term and vim.fn.has("nvim-0.11.4") == 0 then
    opts.term = nil
    ---@diagnostic disable-next-line: deprecated
    return vim.fn.termopen(cmd, get_opts(opts))
  end
  return vim.fn.jobstart(cmd, get_opts(opts))
end

---@class snacks.Job
---@field buf number
---@field cmd string | string[]
---@field opts snacks.job.Opts
---@field lines string[]
---@field line number
---@field id? number
---@field chan? number
---@field killed? boolean
local Job = {}
Job.__index = Job

---@param buf number
---@param cmd string | string[]
---@param opts? snacks.job.Opts
function Job.new(buf, cmd, opts)
  local self = setmetatable({}, Job)
  self.buf = buf
  self.opts = opts or {}
  self.cmd = cmd
  self.lines = { "" }
  self.line = 1
  self:setup()
  if self.opts.start ~= false then
    self:start()
  end
  return self
end

function Job:setup()
  self.opts.term = self.opts.term ~= false
  self.opts.sync = self.opts.sync ~= false
  if self.opts.term and self.opts.input then
    -- NOTE: term jobs do not support input
    self.opts.term, self.opts.ansi = false, true
  end
  local on_output = function(_, data)
    self:on_output(data)
  end
  self.opts.on_stdout = wrap(on_output, self.opts.on_stdout)
  self.opts.on_stderr = wrap(on_output, self.opts.on_stderr)
  self.opts.on_exit = wrap(function(_, code)
    self:on_exit(code)
  end, self.opts.on_exit)
  if not self.opts.term and not self.opts.ansi then
    self.opts.on_line = self.opts.on_line or function(_, text, line)
      self:on_line(text, line)
    end
  end
end

function Job:on_exit(code)
  if not self:buf_valid() then
    return
  end
  self:emit()
  if self.opts.on_lines then
    self.opts.on_lines(self.id, self.lines)
  end
  if self.opts.term then
    self:hide_process_exited()
  end

  self:set_cursor()

  if not self.killed and code ~= 0 then
    self:error(
      ("Job exited with code `%s`"):format(code),
      ("\n- `vim.o.shell = %q`\n\nOutput:\n%s"):format(vim.o.shell, vim.trim(table.concat(self.lines, "\n")))
    )
  end
end

function Job:set_cursor()
  if not self:buf_valid() then
    return
  end
  for _, win in ipairs(vim.fn.win_findbuf(self.buf)) do
    vim.api.nvim_win_set_cursor(win, { 1, 0 })
  end
end

---@param text string
---@param line number
function Job:on_line(text, line)
  if self:buf_valid() then
    vim.bo[self.buf].modifiable = true
    vim.api.nvim_buf_set_lines(self.buf, line == 1 and 0 or -1, -1, true, { text })
    vim.bo[self.buf].modifiable = false
  end
end

---@param msg string
---@param footer? string
function Job:error(msg, footer)
  Snacks.debug.cmd({
    title = "Job Error",
    level = vim.log.levels.ERROR,
    header = msg,
    footer = footer,
    cmd = self.cmd,
    cwd = self.opts.cwd,
    group = true,
  })
end

function Job:start()
  if self.opts.debug then
    vim.schedule(function()
      Snacks.debug.cmd({
        cmd = self.cmd,
        cwd = self.opts.cwd,
        group = true,
        props = {
          cwd = self.opts.cwd,
          term = self.opts.term,
          pty = self.opts.pty,
          input = self.opts.input and "<provided>",
          output = self.opts.output and "<provided>",
          ansi = self.opts.ansi,
        },
      })
    end)
  end

  if self.opts.output or (not self.opts.term and self.opts.ansi) then
    self.chan = vim.api.nvim_open_term(self.buf, {})
    if self.opts.output then
      vim.api.nvim_chan_send(self.chan, self.opts.output)
      return
    end
  end

  self.id = vim.api.nvim_buf_call(self.buf, function()
    return jobstart(self.cmd, self.opts)
  end)

  if self.id <= 0 then
    self.id = nil
    return self:error("Failed to start job")
  end

  vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, {
    buffer = self.buf,
    callback = function()
      self:stop()
    end,
  })

  if self.opts.input then
    vim.fn.chansend(self.id, self.opts.input .. "\n")
    vim.fn.chanclose(self.id, "stdin")
  end
end

function Job:stop()
  if self.id then
    self.killed = true
    vim.fn.jobstop(self.id)
  end
end

function Job:set_lines(from, to, lines)
  if self:buf_valid() then
    vim.bo[self.buf].modifiable = true
    vim.api.nvim_buf_set_lines(self.buf, from, to, true, lines)
    vim.bo[self.buf].modifiable = false
  end
end

function Job:hide_process_exited()
  local timer = assert(vim.uv.new_timer())
  local stop = function()
    return timer:is_active() and timer:stop() == 0 and timer:close()
  end
  local check = function()
    if self:buf_valid() then
      for i, line in ipairs(vim.api.nvim_buf_get_lines(self.buf, 0, -1, true)) do
        if line:find("^%[Process exited 0%]") then
          self:set_lines(i - 1, i, {})
          return stop()
        end
      end
    end
  end
  timer:start(30, 30, vim.schedule_wrap(check))
  vim.defer_fn(stop, 1000)
end

function Job:running()
  return self.id and vim.fn.jobwait({ self.id }, 0)[1] == -1
end

function Job:buf_valid()
  return self.buf and vim.api.nvim_buf_is_valid(self.buf)
end

function Job:emit()
  if not self:buf_valid() then
    return
  end
  while self.line < #self.lines do
    self.lines[self.line] = self.lines[self.line]:gsub("\r$", "")
    if self.opts.on_line then
      self.opts.on_line(self.id, self.lines[self.line], self.line)
    end
    self.line = self.line + 1
  end
end

---@param data string[]
function Job:on_output(data)
  if not self:buf_valid() then
    return
  end
  if self.chan then
    vim.api.nvim_chan_send(self.chan, table.concat(data, "\n"))
  end
  self.lines[#self.lines] = self.lines[#self.lines] .. data[1]
  vim.list_extend(self.lines, data, 2)
  self:emit()
end

function Job:refresh()
  if not self:buf_valid() then
    return
  end
  -- HACK: this forces a refresh of the terminal buffer and prevents flickering
  vim.bo[self.buf].scrollback = 9999
  vim.bo[self.buf].scrollback = 9998
end

M.new = Job.new

return M
