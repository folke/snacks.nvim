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

M.needs_setup = { "bigfile", "notifier", "statuscolumn", "words", "quickfile", "dashboard", "indent", "scroll" }

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
  local root = debug.getinfo(1, "S").source:match("@(.*)")
  root = vim.fn.fnamemodify(root, ":h")
  for file, t in vim.fs.dir(root, { depth = 1 }) do
    local name = t == "file" and file:match("(.*)%.lua") or file
    if name and not vim.tbl_contains({ "init", "docs", "health", "types" }, name) then
      local mod = Snacks[name] --[[@as {health?: fun()}]]
      assert(type(mod) == "table", ("`Snacks.%s` not found"):format(name))
      local opts = Snacks.config[name] or {} --[[@as {enabled?: boolean}]]
      local needs_setup = vim.tbl_contains(M.needs_setup, name)
      if needs_setup or mod.health then
        M.start(("Snacks.%s"):format(name))
        -- M.prefix = ("`Snacks.%s` "):format(name)
        if needs_setup then
          if opts.enabled then
            M.ok("setup {enabled}")
          else
            M.warn("setup {disabled}")
          end
        end
        if mod.health then
          mod.health()
        end
      end
    end
  end
end

return M
