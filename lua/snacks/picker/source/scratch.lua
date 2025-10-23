local M = {}

---@class snacks.scratch.actions
---@field [string] snacks.picker.Action.spec
M.actions = {
  scratch_open = function(picker, item)
    picker:close()
    if not item then
      return
    end
    Snacks.scratch.open({ icon = item.item.icon, file = item.item.file, name = item.item.name, ft = item.item.ft })
  end,
  scratch_delete = function(picker, item)
    local current = item.file
    os.remove(current)
    picker.list:set_selected()
    picker.list:set_target()
    picker:find()
  end,
  scratch_new = function(picker)
    picker:close()
    Snacks.scratch.open()
  end,
}

---@param opts snacks.picker.proc.Config
---@type snacks.picker.finder
function M.scratch(opts)
  local list = Snacks.scratch.list()
  local items = {} ---@type snacks.picker.finder.Item[]
  for _, item in ipairs(list) do
    items[#items + 1] = {
      file = item.file,
      item = item,
      title = item.name,
      text = Snacks.picker.util.text(item, { "name", "branch", "ft" }),
      branch = item.branch and ("branch:%s"):format(item.branch) or "",
    }
  end
  return items
end

---@type snacks.picker.format
function M.format(item, picker)
  local file = item.item
  local ret = {} ---@type snacks.picker.Highlight[]
  local a = Snacks.picker.util.align
  local icon, icon_hl = file.icon, nil
  if not icon then
    icon, icon_hl = Snacks.util.icon(file.ft, "filetype")
  end
  ret[#ret + 1] = { a(icon, 3), icon_hl }
  ret[#ret + 1] = { a(file.name, 20, { truncate = true }) }
  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { a(item.branch, 20, { truncate = true }), "Number" }
  ret[#ret + 1] = { " " }
  ---@diagnostic disable-next-line: missing-fields
  vim.list_extend(ret, Snacks.picker.format.filename({ text = "", dir = true, file = file.cwd }, picker))
  return ret
end

return M
