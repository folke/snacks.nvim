---@class snacks.picker
---@field actions snacks.picker.actions
---@field config snacks.picker.config
---@field format snacks.picker.formatters
---@field preview snacks.picker.previewers
---@field sort snacks.picker.sorters
---@field util snacks.picker.util
---@field current? snacks.Picker
---@field highlight snacks.picker.highlight
---@field resume fun(opts?: snacks.picker.Config):snacks.Picker
---@field sources snacks.picker.sources.Config
---@overload fun(opts: snacks.picker.Config): snacks.Picker
---@overload fun(source: string, opts: snacks.picker.Config): snacks.Picker
local M = setmetatable({}, {
  __call = function(M, ...)
    return M.pick(...)
  end,
  ---@param M snacks.picker
  __index = function(M, k)
    if type(k) ~= "string" then
      return
    end
    local mods = {
      "actions",
      "config",
      "format",
      "preview",
      "util",
      "sort",
      highlight = "util.highlight",
      sources = "config.sources",
    }
    for m, mod in pairs(mods) do
      mod = mod == k and k or m == k and mod or nil
      if mod then
        ---@diagnostic disable-next-line: no-unknown
        M[k] = require("snacks.picker." .. mod)
        return rawget(M, k)
      end
    end
    return M.config.wrap(k, { check = true })
  end,
})

---@type snacks.meta.Meta
M.meta = {
  desc = "Picker for selecting items",
  needs_setup = true,
  merge = { config = "config.defaults", picker = "core.picker", "actions" },
}

---@class snacks.picker.resume.Opts
---@field source? string
---@field include? string[]
---@field exclude? string[]

-- create actual picker functions for autocomplete
vim.defer_fn(function()
  M.config.setup()
end, 10)

--- Create a new picker
---@param source? string
---@param opts? snacks.picker.Config
---@overload fun(opts: snacks.picker.Config): snacks.Picker
function M.pick(source, opts)
  if not opts and type(source) == "table" then
    opts, source = source, nil
  end
  opts = opts or {}
  opts.source = source or opts.source
  -- Show pickers if no source, items or finder is provided
  if not (opts.source or opts.items or opts.finder or opts.multi) then
    opts.source = "pickers"
    return M.pick(opts)
  end
  local current = opts.source and M.get({ source = opts.source })[1]
  if current then
    current:close()
    return
  end
  return require("snacks.picker.core.picker").new(opts)
end

--- Implementation for `vim.ui.select`
---@type snacks.picker.ui_select
function M.select(...)
  return require("snacks.picker.select").select(...)
end

---@private
function M.setup()
  if M.config.get().ui_select then
    vim.ui.select = M.select
  end
end

---@private
function M.health()
  require("snacks.picker.core._health").health()
end

--- Get active pickers, optionally filtered by source,
--- or the current tab
---@param opts? {source?: string, tab?: boolean} tab defaults to true
function M.get(opts)
  return require("snacks.picker.core.picker").get(opts)
end

---@param opts? snacks.picker.resume.Opts
---@overload fun(source:string):snacks.Picker?
---@return snacks.Picker?
function M.resume(opts)
  return require("snacks.picker.resume").resume(opts)
end

return M
