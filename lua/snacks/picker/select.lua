local M = {}

---@alias snacks.picker.ui_select fun(items: any[], opts?: {prompt?: string, format_item?: (fun(item: any): string), kind?: string}, on_choice: fun(item?: any, idx?: number))

---@class snacks.picker.ui_select.Opts: vim.ui.select.Opts
---@field format_item? fun(item: any, is_snacks: boolean):(string|snacks.picker.Highlight[])
---@field picker? snacks.picker.Config

---@generic T
---@param items T[] Arbitrary items
---@param opts? snacks.picker.ui_select.Opts
---@param on_choice fun(item?: T, idx?: number)
function M.select(items, opts, on_choice)
  assert(type(on_choice) == "function", "on_choice must be a function")
  opts = opts or {}

  local title = opts.prompt or "Select"
  title = title:gsub("^%s*", ""):gsub("[%s:]*$", "")
  local completed = false
  opts.kind = opts.kind or (opts.picker and "snacks") or opts.kind

  ---@type snacks.picker.Config
  local picker_opts = {
    source = "select",
    finder = function()
      ---@type snacks.picker.finder.Item[]
      local ret = {}
      for idx, item in ipairs(items) do
        local text = (opts.format_item or tostring)(item)
        ---@type snacks.picker.finder.Item
        local it = type(item) == "table" and setmetatable({}, { __index = item }) or {}
        it.formatted = text
        it.text = idx .. " " .. text
        it.item = item
        it.idx = idx
        ret[#ret + 1] = it
      end
      return ret
    end,
    format = Snacks.picker.format.ui_select(opts),
    title = title,
    layout = opts.picker and opts.picker.layout or {
      preview = false,
      layout = {
        height = math.floor(math.min(vim.o.lines * 0.8 - 10, #items + 2) + 0.5),
      },
    },
    actions = {
      confirm = function(picker, item)
        if completed then
          return
        end
        completed = true
        picker:close()
        vim.schedule(function()
          on_choice(item and item.item, item and item.idx)
        end)
      end,
    },
    on_close = function()
      if completed then
        return
      end
      completed = true
      vim.schedule(on_choice)
    end,
  }
  if opts.picker then
    picker_opts = Snacks.config.merge({}, vim.deepcopy(picker_opts), opts.picker)
  end
  return Snacks.picker.pick(picker_opts)
end

return M
