---@class snacks.image.terminal
---@field transform? fun(data: string): string
local M = {}

local size ---@type snacks.image.terminal.Dim?
---@type snacks.image.Env[]
local environments = {
  {
    name = "kitty",
    terminal = "kitty",
    supported = true,
    placeholders = true,
  },
  {
    name = "ghostty",
    terminal = "ghostty",
    supported = true,
    placeholders = true,
  },
  {
    name = "wezterm",
    terminal = "wezterm",
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

M._terminal = nil ---@type snacks.image.Terminal?

vim.api.nvim_create_autocmd("VimResized", {
  group = vim.api.nvim_create_augroup("snacks.image.terminal", { clear = true }),
  callback = function()
    size = nil
  end,
})

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
      if e.terminal and M._terminal and M._terminal.terminal then
        e.detected = M._terminal.terminal:lower():find(e.terminal:lower()) ~= nil
      end
      if not e.detected then
        for k, v in pairs(e.env or {}) do
          local val = os.getenv(k)
          if val and (v == true or val:find(v)) then
            e.detected = true
            break
          end
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
  opts.q = opts.q ~= false and (opts.q or 2) or nil -- silence all
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
  data = M.transform and M.transform(data) or data
  if vim.api.nvim_ui_send then
    vim.api.nvim_ui_send(data)
  else
    io.stdout:write(data)
  end
end

---@param cb fun(term: snacks.image.Terminal)
function M.detect(cb)
  if M._terminal then
    if M._terminal.pending then
      table.insert(M._terminal.pending, cb)
      return
    end
    return cb(M._terminal)
  end

  ---@class snacks.image.Terminal
  ---@field terminal? string
  ---@field version? string
  ---@field supported? boolean
  ---@field placeholders? boolean
  local ret = {
    terminal = "unknown",
    version = "unknown",
    pending = { cb }, ---@type fun(term: snacks.image.Terminal)[]
  }
  M._terminal = ret

  local function on_done()
    for _, c in ipairs(ret.pending or {}) do
      c(ret)
    end
    ret.pending = nil
  end

  if vim.env.TMUX then
    pcall(vim.fn.system, { "tmux", "set", "-p", "allow-passthrough", "all" })
    M.transform = function(data)
      return ("\027Ptmux;" .. data:gsub("\027", "\027\027")) .. "\027\\"
    end
  end

  local timer = assert(vim.uv.new_timer())
  local done = 0

  local id = vim.api.nvim_create_autocmd("TermResponse", {
    group = vim.api.nvim_create_augroup("image.terminal.detect", { clear = true }),
    callback = function(ev)
      local data = ev.data.sequence
      if data:find("^\27P>|") then
        local term, version = data:match("P>|(%S+)%s*(.*)")
        if term and version then
          ret.terminal = term
          ret.version = version
          done = done + 1
        end
      elseif data:find("^\27_G") then
        local args, ok = data:match("\27_G(.*);(.*)")
        if args then
          local params = {}
          for _, a in ipairs(vim.split(args, ",")) do
            local k, v = a:match("(%S+)=(%S+)")
            if k and v then
              params[k] = v
            end
          end
          if params["i"] == "31" and ok then
            ret.supported = ok == "OK"
            done = done + 1
            -- elseif params["i"] == "32" and ok then
            --   ret.placeholders = ok == "OK"
            --   done = done + 1
          end
        end
      end
      if done < 2 then
        return
      end
      if timer and not timer:is_closing() then
        timer:stop()
        timer:close()
      end
      vim.schedule(on_done)
      return true -- delete autocmd
    end,
  })

  timer:start(1000, 0, function()
    timer:stop()
    timer:close()
    vim.schedule(function()
      vim.api.nvim_del_autocmd(id)
      on_done()
    end)
  end)

  M.request({
    i = 31,
    s = 1,
    v = 1,
    a = "q",
    t = "d",
    f = 24,
    q = false,
    data = "AAAA",
  })

  M.write("\27[>q")
end

function M.setup() end

return M
