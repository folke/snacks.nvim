---@class snacks.terminal: snacks.win
---@field cmd? string | string[]
---@field opts snacks.terminal.Opts
---@overload fun(cmd?: string|string[], opts?: snacks.terminal.Opts): snacks.terminal
local M = setmetatable({}, {
  __call = function(t, ...)
    return t.toggle(...)
  end,
})

M.meta = {
  desc = "Create and toggle floating/split terminals",
}

---@class snacks.terminal.Config
---@field win? snacks.win.Config|{}
---@field shell? string|string[] The shell to use. Defaults to `vim.o.shell`
---@field override? fun(cmd?: string|string[], opts?: snacks.terminal.Opts) Use this to use a different terminal implementation
local defaults = {
  win = { style = "terminal" },
}

---@class snacks.terminal.Opts: snacks.terminal.Config
---@field cwd? string
---@field env? table<string, string>
---@field start_insert? boolean start insert mode when starting the terminal
---@field auto_insert? boolean start insert mode when entering the terminal buffer
---@field auto_close? boolean close the terminal buffer when the process exits
---@field interactive? boolean shortcut for `start_insert`, `auto_close` and `auto_insert` (default: true)

Snacks.config.style("terminal", {
  bo = {
    filetype = "snacks_terminal",
  },
  wo = {},
  keys = {
    q = "hide",
    gf = function(self)
      local f = vim.fn.findfile(vim.fn.expand("<cfile>"), "**")
      if f == "" then
        Snacks.notify.warn("No file under cursor")
      else
        self:hide()
        vim.schedule(function()
          vim.cmd("e " .. f)
        end)
      end
    end,
    term_normal = {
      "<esc>",
      function(self)
        self.esc_timer = self.esc_timer or (vim.uv or vim.loop).new_timer()
        if self.esc_timer:is_active() then
          self.esc_timer:stop()
          vim.cmd("stopinsert")
        else
          self.esc_timer:start(200, 0, function() end)
          return "<esc>"
        end
      end,
      mode = "t",
      expr = true,
      desc = "Double escape to normal mode",
    },
  },
})

---@type table<string, snacks.win>
local terminals = {}

local function jobstart(cmd, opts)
  opts = opts or {}
  local fn = vim.fn.jobstart
  if vim.fn.termopen then
    opts.term = nil
    fn = vim.fn.termopen
  end
  return fn(cmd, vim.tbl_isempty(opts) and vim.empty_dict() or opts)
end

--- Open a new terminal window.
---@param cmd? string | string[]
---@param opts? snacks.terminal.Opts
function M.open(cmd, opts)
  local id = vim.v.count1
  opts = Snacks.config.get("terminal", defaults --[[@as snacks.terminal.Opts]], opts)
  opts.win = Snacks.win.resolve("terminal", {
    position = cmd and "float" or "bottom",
  }, opts.win, { show = false })
  opts = vim.deepcopy(opts)
  opts.win.wo.winbar = opts.win.wo.winbar
    or (opts.win.position == "float" and "" or (id .. ": %{get(b:, 'term_title', '')}"))

  if opts.override then
    return opts.override(cmd, opts)
  end

  local interactive = opts.interactive ~= false
  local auto_insert = opts.auto_insert or (opts.auto_insert == nil and interactive)
  local start_insert = opts.start_insert or (opts.start_insert == nil and interactive)
  local auto_close = opts.auto_close or (opts.auto_close == nil and interactive)

  local on_buf = opts.win and opts.win.on_buf
  ---@param self snacks.terminal
  opts.win.on_buf = function(self)
    self.cmd = cmd
    vim.b[self.buf].snacks_terminal = { cmd = cmd, id = id }
    if on_buf then
      on_buf(self)
    end
  end

  local on_win = opts.win and opts.win.on_win
  ---@param self snacks.terminal
  opts.win.on_win = function(self)
    if start_insert and vim.api.nvim_get_current_buf() == self.buf then
      vim.cmd.startinsert()
    end
    if on_win then
      on_win(self)
    end
  end

  local terminal = Snacks.win(opts.win)

  if auto_insert then
    terminal:on("BufEnter", function()
      vim.cmd.startinsert()
    end, { buf = true })
  end

  if auto_close then
    terminal:on("TermClose", function()
      if type(vim.v.event) == "table" and vim.v.event.status ~= 0 then
        Snacks.notify.error("Terminal exited with code " .. vim.v.event.status .. ".\nCheck for any errors.")
        return
      end
      terminal:close()
      vim.cmd.checktime()
    end, { buf = true })
  end

  terminal:on("ExitPre", function()
    terminal:close()
  end)

  terminal:on("BufWipeout", function()
    vim.schedule(function()
      terminal:close()
    end)
  end, { buf = true })

  terminal:show()
  vim.api.nvim_buf_call(terminal.buf, function()
    jobstart(cmd or M.parse(opts.shell or vim.o.shell), {
      cwd = opts.cwd,
      env = opts.env,
      term = true,
    })
  end)

  vim.cmd("noh")
  return terminal
end

--- Get or create a terminal window.
--- The terminal id is based on the `cmd`, `cwd`, `env` and `vim.v.count1` options.
--- `opts.create` defaults to `true`.
---@param cmd? string | string[]
---@param opts? snacks.terminal.Opts| {create?: boolean}
---@return snacks.win? terminal, boolean? created
function M.get(cmd, opts)
  opts = opts or {}
  local id = vim.inspect({ cmd = cmd, cwd = opts.cwd, env = opts.env, count = vim.v.count1 })
  local created = false
  if not (terminals[id] and terminals[id]:buf_valid()) and (opts.create ~= false) then
    local ret = M.open(cmd, opts)
    ret:on("BufWipeout", function()
      terminals[id] = nil
    end, { buf = true })
    terminals[id] = ret
    created = true
  end
  return terminals[id], created
end

---@return snacks.win[]
function M.list()
  return vim.tbl_filter(function(t)
    return t:buf_valid()
  end, terminals)
end

--- Toggle a terminal window.
--- The terminal id is based on the `cmd`, `cwd`, `env` and `vim.v.count1` options.
---@param cmd? string | string[]
---@param opts? snacks.terminal.Opts
function M.toggle(cmd, opts)
  local terminal, created = M.get(cmd, opts)
  return created and terminal or assert(terminal):toggle()
end

--- Parses a shell command into a table of arguments.
--- - spaces inside quotes (only double quotes are supported) are preserved
--- - backslash
---@private
---@param cmd string|string[]
---@return string[]
function M.parse(cmd)
  if type(cmd) == "table" then
    return cmd
  end
  local args = {}
  local in_quotes, escape_next, current = false, false, ""
  local function add()
    if #current > 0 then
      table.insert(args, current)
      current = ""
    end
  end

  for i = 1, #cmd do
    local char = cmd:sub(i, i)
    if escape_next then
      current = current .. ((char == '"' or char == "\\") and "" or "\\") .. char
      escape_next = false
    elseif char == "\\" and in_quotes then
      escape_next = true
    elseif char == '"' then
      in_quotes = not in_quotes
    elseif char:find("[ \t]") and not in_quotes then
      add()
    else
      current = current .. char
    end
  end
  add()
  return args
end

--- Colorize the current buffer.
--- Replaces ansii color codes with the actual colors.
---
--- Example:
---
--- ```sh
--- ls -la --color=always | nvim - -c "lua Snacks.terminal.colorize()"
--- ```
function M.colorize()
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.statuscolumn = ""
  vim.wo.signcolumn = "no"
  vim.opt.listchars = { space = " " }

  local buf = vim.api.nvim_get_current_buf()

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  while #lines > 0 and vim.trim(lines[#lines]) == "" do
    lines[#lines] = nil
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})

  vim.api.nvim_chan_send(vim.api.nvim_open_term(buf, {}), table.concat(lines, "\r\n"))
  vim.keymap.set("n", "q", "<cmd>q<cr>", { silent = true, buffer = buf })
  vim.api.nvim_create_autocmd("TextChanged", {
    buffer = buf,
    callback = function()
      pcall(vim.api.nvim_win_set_cursor, 0, { #lines, 0 })
    end,
  })
  vim.api.nvim_create_autocmd("TermEnter", { buffer = buf, command = "stopinsert" })
end

---@private
function M.health()
  local opts = Snacks.config.get("terminal", defaults --[[@as snacks.terminal.Opts]])
  local cmd = M.parse(opts.shell or vim.o.shell)
  local ok = cmd[1] and (vim.fn.executable(cmd[1]) == 1)
  local msg = ("shell %s\n- `vim.o.shell`: %s\n- `parsed`: %s"):format(
    ok and "configured" or "not found",
    vim.o.shell,
    vim.inspect(cmd)
  )
  Snacks.health[ok and "ok" or "error"](msg)
end

return M
