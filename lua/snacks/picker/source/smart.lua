local M = {}

---@class snacks.picker
---@field smart fun(opts?: snacks.picker.smart.Config): snacks.picker.finder

local BONUS_FRECENCY = 8
local BONUS_CWD = 10

---@param opts snacks.picker.smart.Config
---@type snacks.picker.finder
function M.smart(opts, filter)
  local frecency = require("snacks.picker.core.frecency").new()
  local done = {} ---@type table<string, boolean>
  local cwd = vim.fs.normalize(opts.cwd or (vim.uv or vim.loop).cwd() or ".")
  local finder = Snacks.picker.config.finder(opts.finders or { "files", "buffers", "recent" })
  return require("snacks.picker.core.finder").wrap(finder, function(item)
    local path = Snacks.picker.util.path(item)
    if not path or done[path] then
      return false
    end
    done[path] = true
    local score = (1 - 1 / (1 + frecency:get(item))) * BONUS_FRECENCY
    item.frecency = score
    if path:find(cwd, 1, true) then
      score = score + BONUS_CWD
    end
    item.score_add = score
  end)(opts, filter)
end

return M
