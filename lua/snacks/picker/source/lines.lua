local M = {}

---@param opts snacks.picker.lines.Config
---@type snacks.picker.finder
function M.lines(opts, ctx)
  local buf = opts.buf or ctx.filter.current_buf
  buf = buf == 0 and vim.api.nvim_get_current_buf() or buf
  local extmarks = require("snacks.picker.util.highlight").get_highlights({ buf = buf, extmarks = true })
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local items = {} ---@type snacks.picker.finder.Item[]
  for l, line in ipairs(lines) do
    ---@type snacks.picker.finder.Item
    local item = {
      buf = buf,
      text = line,
      pos = { l, (line:find("%S") or 1) - 1 },
      highlights = extmarks[l],
    }
    items[#items + 1] = item
  end
  return items
end

return M
