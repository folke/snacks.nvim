---@class Snacks: snacks.plugins
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

---@class snacks.Config: snacks.plugins.Config
---@field styles? table<string, snacks.win.Config>
local config = {}
config.styles = {}

---@class snacks.config: snacks.Config
M.config = setmetatable({}, {
  __index = function(_, k)
    config[k] = config[k] or {}
    return config[k]
  end,
  __newindex = function(_, k, v)
    config[k] = v
  end,
})

local islist = vim.islist or vim.tbl_islist
local is_dict_like = function(v) -- has string and number keys
  return type(v) == "table" and (vim.tbl_isempty(v) or not islist(v))
end
local is_dict = function(v) -- has only string keys
  return type(v) == "table" and (vim.tbl_isempty(v) or not v[1])
end

--- Merges the values similar to vim.tbl_deep_extend with the **force** behavior,
--- but the values can be any type
---@generic T
---@param ... T
---@return T
function M.config.merge(...)
  local ret = select(1, ...)
  for i = 2, select("#", ...) do
    local value = select(i, ...)
    if is_dict_like(ret) and is_dict(value) then
      for k, v in pairs(value) do
        ret[k] = M.config.merge(ret[k], v)
      end
    elseif value ~= nil then
      ret = value
    end
  end
  return ret
end

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
  local merge, todo = {}, { defaults, config[snack] or {}, ... }
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
  local ret = M.config.merge(unpack(merge))
  if type(ret.config) == "function" then
    ret.config(ret, defaults)
  end
  return ret
end

--- Register a new window style config.
---@param name string
---@param defaults snacks.win.Config|{}
---@return string
function M.config.style(name, defaults)
  config.styles[name] = vim.tbl_deep_extend("force", vim.deepcopy(defaults), config.styles[name] or {})
  return name
end

M.did_setup = false
M.did_setup_after_vim_enter = false

---@param opts snacks.Config?
function M.setup(opts)
  if M.did_setup then
    return vim.notify("snacks.nvim is already setup", vim.log.levels.ERROR, { title = "snacks.nvim" })
  end
  M.did_setup = true

  if vim.fn.has("nvim-0.9.4") ~= 1 then
    return vim.notify("snacks.nvim requires Neovim >= 0.9.4", vim.log.levels.ERROR, { title = "snacks.nvim" })
  end

  -- enable all by default when config is passed
  opts = opts or {}
  for k in pairs(opts) do
    opts[k].enabled = opts[k].enabled == nil or opts[k].enabled
  end
  config = vim.tbl_deep_extend("force", config, opts or {})

  local events = {
    BufReadPre = { "bigfile" },
    BufReadPost = { "quickfile", "indent" },
    LspAttach = { "words" },
    UIEnter = { "dashboard", "scroll", "input", "scope", "picker" },
  }

  local function load(event)
    for _, snack in ipairs(events[event] or {}) do
      if M.config[snack] and M.config[snack].enabled then
        (M[snack].setup or M[snack].enable)()
      end
    end
    events[event] = nil
  end

  if vim.v.vim_did_enter == 1 then
    M.did_setup_after_vim_enter = true
    load("UIEnter")
  end

  vim.api.nvim_create_autocmd(vim.tbl_keys(events), {
    group = vim.api.nvim_create_augroup("snacks", { clear = true }),
    once = true,
    nested = true,
    callback = function(ev)
      load(ev.event)
    end,
  })

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
