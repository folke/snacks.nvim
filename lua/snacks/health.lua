---@class snacks.health
---@field ok fun(msg: string)
---@field warn fun(msg: string)
---@field error fun(msg: string)
---@field info fun(msg: string)
---@field start fun(msg: string)
local M = setmetatable({}, {
  __index = function(M, k)
    return function(msg)
      return require("vim.health")[k](M.prefix .. msg)
    end
  end,
})
M.prefix = ""

M.meta = {
  desc = "Snacks health checks",
  readme = false,
  health = false,
}

function M.check()
  M.prefix = ""
  M.start("Snacks")
  if Snacks.did_setup then
    M.ok("setup called")
    if Snacks.did_setup_after_vim_enter then
      M.warn("setup called *after* `VimEnter`")
    end
  else
    M.error("setup not called")
  end
  if package.loaded.lazy then
    local plugin = require("lazy.core.config").spec.plugins["snacks.nvim"]
    if plugin then
      if plugin.lazy ~= false then
        M.warn("`snacks.nvim` should not be lazy-loaded. Add `lazy=false` to the plugin spec")
      end
      if (plugin.priority or 0) < 1000 then
        M.warn("`snacks.nvim` should have a priority of 1000 or higher. Add `priority=1000` to the plugin spec")
      end
    else
      M.error("`snacks.nvim` not found in lazy")
    end
  end
  for _, plugin in ipairs(Snacks.meta.get()) do
    local opts = Snacks.config[plugin.name] or {} --[[@as {enabled?: boolean}]]
    if plugin.meta.health ~= false and (plugin.meta.needs_setup or plugin.health) then
      M.start(("Snacks.%s"):format(plugin.name))
      -- M.prefix = ("`Snacks.%s` "):format(name)
      if plugin.meta.needs_setup then
        if opts.enabled then
          M.ok("setup {enabled}")
        else
          M.warn("setup {disabled}")
        end
      end
      if plugin.health then
        plugin.health()
      end
    end
  end
end

return M
