local M = {}

---@alias snacks.picker.ui_select fun(items: any[], opts?: {prompt?: string, format_item?: (fun(item: any): string), kind?: string}, on_choice: fun(item?: any, idx?: number))

---@generic T
---@param items T[] Arbitrary items
---@param opts? {prompt?: string, format_item?: (fun(item: T): string), kind?: string}
---@param on_choice fun(item?: T, idx?: number)
function M.select(items, opts, on_choice)
  assert(type(on_choice) == "function", "on_choice must be a function")
  opts = opts or {}

  ---@type snacks.picker.finder.Item[]
  local finder_items = {}
  for idx, item in ipairs(items) do
    local text = (opts.format_item or tostring)(item)
    table.insert(finder_items, {
      formatted = text,
      text = idx .. " " .. text,
      item = item,
      idx = idx,
    })
  end

  local title = opts.prompt or "Select"
  title = title:gsub("^%s*", ""):gsub("[%s:]*$", "")

  ---@type snacks.picker.finder.Item[]
  return Snacks.picker.pick({
    source = "select",
    items = finder_items,
    format = Snacks.picker.format.ui_select(opts.kind, #items),
    title = title,
    layout = {
      preview = false,
      layout = {
        height = math.floor(math.min(vim.o.lines * 0.8 - 10, #items + 2) + 0.5),
      },
    },
    actions = {
      confirm = function(picker, item)
        picker:close()
        vim.schedule(function()
          on_choice(item and item.item, item and item.idx)
        end)
      end,
    },
  })
end

return M
