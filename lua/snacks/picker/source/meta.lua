local M = {}

---@param file string
---@param t table<string,unknown>
function M.table(file, t)
  file = Snacks.meta.file(file)
  local values = vim.tbl_keys(t)
  table.sort(values)
  ---@param value string
  return vim.tbl_map(function(value)
    return {
      file = file,
      text = value,
      search = ("/^M\\.%s = \\|function M\\.%s("):format(value, value),
    }
  end, values)
end

---@param opts snacks.picker.Config
---@type snacks.picker.finder
function M.pickers(opts)
  return M.table("picker/config/sources.lua", opts.sources or {})
end

---@param opts snacks.picker.Config
---@type snacks.picker.finder
function M.layouts(opts)
  return M.table("picker/config/layouts.lua", opts.layouts or {})
end

function M.actions()
  return M.table("picker/actions.lua", require("snacks.picker.actions"))
end

function M.preview()
  return M.table("picker/preview.lua", require("snacks.picker.preview"))
end

function M.format()
  return M.table("picker/format.lua", require("snacks.picker.format"))
end

return M
