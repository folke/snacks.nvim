---@class snacks.picker.transformers
---@field [string] snacks.picker.transform
local M = {}

function M.unique_file(item, ctx)
  ctx.meta.done = ctx.meta.done or {} ---@type table<string, boolean>
  local path = Snacks.picker.util.path(item)
  if not path or ctx.meta.done[path] then
    return false
  end
  ctx.meta.done[path] = true
end

function M.text_to_file(item, ctx)
  item.file = item.file or item.text
end

return M
