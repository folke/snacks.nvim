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

M.needs_setup = { "bigfile", "notifier", "statuscolumn", "words", "quickfile", "dashboard" }

function M.check()
  M.prefix = ""
  M.start("Snacks")
  if Snacks.did_setup then
    M.ok("setup called")
  else
    M.error("setup not called")
  end
  local root = debug.getinfo(1, "S").source:match("@(.*)")
  root = vim.fn.fnamemodify(root, ":h")
  for file, t in vim.fs.dir(root, { depth = 1 }) do
    local name = file:match("(.*)%.lua")
    if t == "file" and name and not vim.tbl_contains({ "init", "docs", "health" }, name) then
      local mod = Snacks[name] --[[@as {health?: fun()}]]
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
