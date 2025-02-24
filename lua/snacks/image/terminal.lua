---@class snacks.image.terminal
local M = {}

local size ---@type snacks.image.terminal.Dim?
---@type snacks.image.Env[]
local environments = {
  {
    name = "kitty",
    env = { TERM = "kitty", KITTY_PID = true },
    supported = true,
    placeholders = true,
  },
  {
    name = "ghostty",
    env = { TERM = "ghostty", GHOSTTY_BIN_DIR = true },
    supported = true,
    placeholders = true,
  },
  {
    name = "wezterm",
    env = {
      TERM = "wezterm",
      WEZTERM_PANE = true,
      WEZTERM_EXECUTABLE = true,
      WEZTERM_CONFIG_FILE = true,
      SNACKS_WEZTERM = true,
    },
    supported = true,
    placeholders = false,
  },
  {
    name = "tmux",
    env = { TERM = "tmux", TMUX = true },
    setup = function()
      pcall(vim.fn.system, { "tmux", "set", "-p", "allow-passthrough", "all" })
    end,
    transform = function(data)
      return ("\027Ptmux;" .. data:gsub("\027", "\027\027")) .. "\027\\"
    end,
  },
  { name = "zellij", env = { TERM = "zellij", ZELLIJ = true }, supported = false, placeholders = false },
  { name = "ssh", env = { SSH_CLIENT = true, SSH_CONNECTION = true }, remote = true },
}

M._env = nil ---@type snacks.image.Env?

vim.api.nvim_create_autocmd("VimResized", {
  group = vim.api.nvim_create_augroup("snacks.image.terminal", { clear = true }),
  callback = function()
    size = nil
  end,
})

-- HACK: ghostty doesn't like it when sending images too fast,
-- after Neovim startup, so we delay the first image
local queue = {} ---@type string[]?
vim.defer_fn(
  vim.schedule_wrap(function()
    for _, data in ipairs(queue or {}) do
      io.stdout:write(data)
    end
    queue = nil
  end),
  100
)

function M.size()
  if size then
    return size
  end
  local ffi = require("ffi")
  ffi.cdef([[
    typedef struct {
      unsigned short row;
      unsigned short col;
      unsigned short xpixel;
      unsigned short ypixel;
    } winsize;
    int ioctl(int, int, ...);
  ]])

  local TIOCGWINSZ = nil
  if vim.fn.has("linux") == 1 then
    TIOCGWINSZ = 0x5413
  elseif vim.fn.has("mac") == 1 or vim.fn.has("bsd") == 1 then
    TIOCGWINSZ = 0x40087468
  end

  local dw, dh = 9, 18
  ---@class snacks.image.terminal.Dim
  size = {
    width = vim.o.columns * dw,
    height = vim.o.lines * dh,
    columns = vim.o.columns,
    rows = vim.o.lines,
    cell_width = dw,
    cell_height = dh,
    scale = dw / 8,
  }

  pcall(function()
    ---@type { row: number, col: number, xpixel: number, ypixel: number }
    local sz = ffi.new("winsize")
    if ffi.C.ioctl(1, TIOCGWINSZ, sz) ~= 0 or sz.col == 0 or sz.row == 0 then
      return
    end
    size = {
      width = sz.xpixel,
      height = sz.ypixel,
      columns = sz.col,
      rows = sz.row,
      cell_width = sz.xpixel / sz.col,
      cell_height = sz.ypixel / sz.row,
      -- try to guess dpi scale
      scale = math.max(1, sz.xpixel / sz.col / 8),
    }
  end)

  return size
end

function M.envs()
  return environments
end

function M.env()
  if M._env then
    return M._env
  end
  M._env = {
    name = "",
    env = {},
  }
  for _, e in ipairs(environments) do
    local override = os.getenv("SNACKS_" .. e.name:upper())
    if override then
      e.detected = override ~= "0" and override ~= "false"
    else
      for k, v in pairs(e.env) do
        local val = os.getenv(k)
        if val and (v == true or val:find(v)) then
          e.detected = true
          break
        end
      end
    end
    if e.detected then
      M._env.name = M._env.name .. "/" .. e.name
      if e.supported ~= nil then
        M._env.supported = e.supported
      end
      if e.placeholders ~= nil then
        M._env.placeholders = e.placeholders
      end
      M._env.transform = e.transform or M._env.transform
      M._env.remote = e.remote or M._env.remote
      if e.setup then
        e.setup()
      end
    end
  end
  M._env.name = M._env.name:gsub("^/", "")
  return M._env
end

---@param opts table<string, string|number>|{data?: string}
function M.request(opts)
  opts.q = opts.q or 2 -- silence all
  local msg = {} ---@type string[]
  for k, v in pairs(opts) do
    if k ~= "data" then
      table.insert(msg, string.format("%s=%s", k, v))
    end
  end
  msg = { table.concat(msg, ",") }
  if opts.data then
    msg[#msg + 1] = ";"
    msg[#msg + 1] = tostring(opts.data)
  end
  local data = "\27_G" .. table.concat(msg) .. "\27\\"
  local env = M.env()
  if env.transform then
    data = env.transform(data)
  end
  if Snacks.image.config.debug.request and opts.m ~= 1 then
    Snacks.debug.inspect(opts)
  end
  M.write(data)
end

---@param pos {[1]: number, [2]: number}
function M.set_cursor(pos)
  M.write("\27[" .. pos[1] .. ";" .. (pos[2] + 1) .. "H")
end

function M.write(data)
  if queue then
    table.insert(queue, data)
  else
    io.stdout:write(data)
  end
end

return M
