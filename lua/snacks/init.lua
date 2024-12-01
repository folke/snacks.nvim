---@class Snacks
---@field bigfile snacks.bigfile
---@field bufdelete snacks.bufdelete
---@field config snacks.config
---@field dashboard snacks.dashboard
---@field debug snacks.debug
---@field git snacks.git
---@field gitbrowse snacks.gitbrowse
---@field lazygit snacks.lazygit
---@field notifier snacks.notifier
---@field notify snacks.notify
---@field quickfile snacks.quickfile
---@field health snacks.health
---@field profiler snacks.profiler
---@field rename snacks.rename
---@field scratch snacks.scratch
---@field statuscolumn snacks.statuscolumn
---@field terminal snacks.terminal
---@field toggle snacks.toggle
---@field util snacks.util
---@field win snacks.win
---@field words snacks.words
local M = {}

setmetatable(M, {
  __index = function(t, k)
    ---@diagnostic disable-next-line: no-unknown
    t[k] = require("snacks." .. k)
    return rawget(t, k)
  end,
})

_G.Snacks = M

---@class snacks.Config.base
---@field example? string
---@field config? fun(opts: table, defaults: table)

---@class snacks.Config
---@field bigfile? snacks.bigfile.Config | { enabled: boolean }
---@field gitbrowse? snacks.gitbrowse.Config
---@field lazygit? snacks.lazygit.Config
---@field notifier? snacks.notifier.Config | { enabled: boolean }
---@field quickfile? { enabled: boolean }
---@field statuscolumn? snacks.statuscolumn.Config  | { enabled: boolean }
---@field styles? table<string, snacks.win.Config>
---@field dashboard? snacks.dashboard.Config  | { enabled: boolean }
---@field terminal? snacks.terminal.Config
---@field toggle? snacks.toggle.Config
---@field win? snacks.win.Config
---@field words? snacks.words.Config
local config = {
  styles = {},
  bigfile = { enabled = false },
  dashboard = { enabled = false },
  notifier = { enabled = false },
  quickfile = { enabled = false },
  statuscolumn = { enabled = false },
  words = { enabled = false },
}

---@class snacks.config: snacks.Config
M.config = setmetatable({}, {
  __index = function(_, k)
    return config[k]
  end,
})

--- Get an example config from the docs/examples directory.
---@param snack string
---@param name string
---@param opts? table
function M.config.example(snack, name, opts)
  local path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h") .. "/docs/examples/" .. snack .. ".lua"
  local ok, ret = pcall(function()
    return loadfile(path)().examples[name] or error(("`%s` not found"):format(name))
  end)
  if not ok then
    M.notify.error(("Failed to load `%s.%s`:\n%s"):format(snack, name, ret))
  end
  return ok and vim.tbl_deep_extend("force", {}, vim.deepcopy(ret), opts or {}) or {}
end

---@generic T: table
---@param snack string
---@param defaults T
---@param ... T[]
---@return T
function M.config.get(snack, defaults, ...)
  local merge, todo = {}, { defaults, config[snack], ... }
  for i = 1, select("#", ...) + 2 do
    local v = todo[i] --[[@as snacks.Config.base]]
    if type(v) == "table" then
      if v.example then
        table.insert(merge, vim.deepcopy(M.config.example(snack, v.example)))
        v.example = nil
      end
      table.insert(merge, vim.deepcopy(v))
    end
  end
  local ret = #merge == 1 and merge[1] or vim.tbl_deep_extend("force", unpack(merge)) --[[@as snacks.Config.base]]
  if type(ret.config) == "function" then
    ret.config(ret, defaults)
  end
  return ret
end

--- Register a new window style config.
---@param name string
---@param defaults snacks.win.Config
function M.config.style(name, defaults)
  config.styles[name] = vim.tbl_deep_extend("force", vim.deepcopy(defaults), config.styles[name] or {})
end

M.did_setup = false

---@param opts snacks.Config?
function M.setup(opts)
  if M.did_setup then
    return vim.notify("snacks.nvim is already setup", vim.log.levels.ERROR, { title = "snacks.nvim" })
  end
  M.did_setup = true
  opts = opts or {}
  -- enable all by default when config is passed
  for k in pairs(opts) do
    opts[k].enabled = opts[k].enabled == nil or opts[k].enabled
  end
  config = vim.tbl_deep_extend("force", config, opts or {})

  if vim.fn.has("nvim-0.9.4") ~= 1 then
    return vim.notify("snacks.nvim requires Neovim >= 0.9.4", vim.log.levels.ERROR, { title = "snacks.nvim" })
  end

  if vim.v.vim_did_enter == 1 and M.config.dashboard.enabled then
    M.dashboard.setup()
  end

  local group = vim.api.nvim_create_augroup("snacks", { clear = true })

  local events = {
    BufReadPre = { "bigfile" },
    BufReadPost = { "quickfile" },
    LspAttach = { "words" },
    UIEnter = { "dashboard" },
  }

  for event, snacks in pairs(events) do
    vim.api.nvim_create_autocmd(event, {
      group = group,
      once = true,
      nested = true,
      callback = function()
        for _, snack in ipairs(snacks) do
          if M.config[snack].enabled then
            M[snack].setup()
          end
        end
      end,
    })
  end

  if M.config.statuscolumn.enabled then
    vim.o.statuscolumn = [[%!v:lua.require'snacks.statuscolumn'.get()]]
  end

  if M.config.notifier.enabled then
    vim.notify = function(msg, level, o)
      vim.notify = Snacks.notifier.notify
      return Snacks.notifier.notify(msg, level, o)
    end
  end
end

return M
