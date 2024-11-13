---@class snacks.terminal: snacks.win
---@field cmd? string | string[]
---@field opts snacks.terminal.Opts
---@overload fun(cmd?: string|string[], opts?: snacks.terminal.Opts): snacks.terminal
local M = setmetatable({}, {
  __call = function(t, ...)
    return t.toggle(...)
  end,
})

---@class snacks.terminal.Config
---@field win? snacks.win.Config
---@field override? fun(cmd?: string|string[], opts?: snacks.terminal.Opts) Use this to use a different terminal implementation
local defaults = {
  win = { style = "terminal" },
}

---@class snacks.terminal.Opts: snacks.terminal.Config
---@field cwd? string
---@field env? table<string, string>
---@field interactive? boolean

Snacks.config.style("terminal", {
  bo = {
    filetype = "snacks_terminal",
  },
  wo = {},
  keys = {
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

--- Open a new terminal window.
---@param cmd? string | string[]
---@param opts? snacks.terminal.Opts
function M.open(cmd, opts)
  local id = vim.v.count1
  opts = Snacks.config.get("terminal", defaults --[[@as snacks.terminal.Opts]], opts)
  opts.win = Snacks.win.resolve("terminal", {
    position = cmd and "float" or "bottom",
  }, opts.win)
  opts.win.wo.winbar = opts.win.wo.winbar or (opts.win.position == "float" and "" or (id .. ": %{b:term_title}"))

  if opts.override then
    return opts.override(cmd, opts)
  end

  local on_buf = opts.win and opts.win.on_buf

  ---@param self snacks.terminal
  opts.win.on_buf = function(self)
    self.cmd = cmd
    vim.b[self.buf].snacks_terminal = { cmd = cmd, id = id }
    if on_buf then
      on_buf(self)
    end
  end

  local terminal = Snacks.win(opts.win)

  vim.api.nvim_buf_call(terminal.buf, function()
    local term_opts = {
      cwd = opts.cwd,
      env = opts.env,
    }
    vim.fn.termopen(cmd or vim.o.shell, vim.tbl_isempty(term_opts) and vim.empty_dict() or term_opts)
  end)

  if opts.interactive ~= false then
    vim.cmd.startinsert()
    vim.api.nvim_create_autocmd("TermClose", {
      once = true,
      buffer = terminal.buf,
      callback = function()
        terminal:close()
        vim.cmd.checktime()
      end,
    })
    vim.api.nvim_create_autocmd("BufEnter", {
      buffer = terminal.buf,
      callback = function()
        vim.cmd.startinsert()
      end,
    })
  end
  vim.cmd("noh")
  return terminal
end

--- Toggle a terminal window.
--- The terminal id is based on the `cmd`, `cwd`, `env` and `vim.v.count1` options.
---@param cmd? string | string[]
---@param opts? snacks.terminal.Opts
function M.toggle(cmd, opts)
  opts = opts or {}

  local id = vim.inspect({ cmd = cmd, cwd = opts.cwd, env = opts.env, count = vim.v.count1 })

  if terminals[id] and terminals[id]:buf_valid() then
    terminals[id]:toggle()
  else
    terminals[id] = M.open(cmd, opts)
  end
  return terminals[id]
end

return M
