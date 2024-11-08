---@class Snacks
---@field config snacks.config
---@field bigfile snacks.bigfile
---@field bufdelete snacks.bufdelete
---@field debug snacks.debug
---@field git snacks.git
---@field gitbrowse snacks.gitbrowse
---@field input snacks.input
---@field lazygit snacks.lazygit
---@field notifier snacks.notifier
---@field notify snacks.notify
---@field quickfile snacks.quickfile
---@field rename snacks.rename
---@field statuscolumn snacks.statuscolumn
---@field terminal snacks.terminal
---@field toggle snacks.toggle
---@field win snacks.win
---@field words snacks.words
local M = {}

setmetatable(M, {
  __index = function(t, k)
    ---@diagnostic disable-next-line: no-unknown
    t[k] = require("snacks." .. k)
    return t[k]
  end,
})

_G.Snacks = M

---@class snacks.Config
---@field bigfile? snacks.bigfile.Config | { enabled: boolean }
---@field gitbrowse? snacks.gitbrowse.Config
---@field input? snacks.input.Config
---@field lazygit? snacks.lazygit.Config
---@field notifier? snacks.notifier.Config | { enabled: boolean }
---@field quickfile? { enabled: boolean }
---@field statuscolumn? snacks.statuscolumn.Config  | { enabled: boolean }
---@field terminal? snacks.terminal.Config
---@field toggle? snacks.toggle.Config
---@field styles? table<string, snacks.win.Config>
---@field win? snacks.win.Config
---@field words? snacks.words.Config
local config = {
  styles = {},
  bigfile = { enabled = true },
  notifier = { enabled = true },
  quickfile = { enabled = true },
  statuscolumn = { enabled = true },
  words = { enabled = true },
}

---@class snacks.config: snacks.Config
M.config = setmetatable({}, {
  __index = function(_, k)
    return config[k]
  end,
})

---@generic T: table
---@param snack string
---@param defaults T
---@param ... T[]
---@return T
function M.config.get(snack, defaults, ...)
  local merge = { vim.deepcopy(defaults), vim.deepcopy(config[snack] or {}) }
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    if v then
      table.insert(merge, vim.deepcopy(v))
    end
  end
  return vim.tbl_deep_extend("force", unpack(merge))
end

--- Register a new window style config.
---@param name string
---@param defaults snacks.win.Config
function M.config.style(name, defaults)
  config.styles[name] = vim.tbl_deep_extend("force", vim.deepcopy(defaults), config.styles[name] or {})
end

---@param opts snacks.Config?
function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})

  local group = vim.api.nvim_create_augroup("snacks", { clear = true })

  local events = {
    BufReadPre = { "bigfile" },
    BufReadPost = { "quickfile" },
    LspAttach = { "words" },
  }

  for event, snacks in pairs(events) do
    vim.api.nvim_create_autocmd(event, {
      group = group,
      once = true,
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
