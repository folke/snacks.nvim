local M = {}

---@alias vim.ui.select.on_choice fun(item?: any, idx?: number)
---@alias snacks.picker.ui_select fun(items: any[], opts?: snacks.picker.ui_select.Opts, on_choice: vim.ui.select.on_choice)

---@class snacks.picker.ui_select.Opts: vim.ui.select.Opts
---@field format_item? fun(item: any, supports_chunks: boolean):(string|snacks.picker.Highlight[])
---@field preview_item? fun(item: any): { buf?: number, pos?: { [1]: integer, [2]: integer } }?
---@field snacks? snacks.picker.Config

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

  ---@type snacks.picker.select.Config
  local picker_opts = {
    source = "select",
    finder = function()
      ---@type snacks.picker.finder.Item[]
      local ret = {}
      for idx, item in ipairs(items) do
        local text = (opts.format_item or tostring)(item)
        ---@type snacks.picker.finder.Item
        local it = type(item) == "table" and setmetatable({}, { __index = item }) or {}
        it.text = idx .. " " .. text
        it.item = item
        it.idx = idx
        ret[#ret + 1] = it
      end
      return ret
    end,
    format = Snacks.picker.format.ui_select(opts),
    title = title,
    layout = {
      config = function(layout)
        -- Fit list height to number of items, up to 10
        for _, box in ipairs(layout.layout) do
          if box.win == "list" and not box.height then
            box.height = math.max(math.min(#items, vim.o.lines * 0.8 - 10), 2)
          end
        end
        if opts.preview_item and layout.hidden then
          layout.hidden = vim.tbl_filter(function(w)
            return w ~= "preview"
          end, layout.hidden)
        end
      end,
    },
    preview = opts.preview_item and function(ctx)
      local ok, data = pcall(opts.preview_item, ctx.item.item)
      if not ok or type(data) ~= "table" or type(data.buf) ~= "number" or not vim.api.nvim_buf_is_valid(data.buf) then
        ctx.preview:reset()
        ctx.preview:notify("no preview available", "warn")
        return
      end
      ctx.preview:set_title(vim.api.nvim_buf_get_name(data.buf) ~= "" and vim.fn.fnamemodify(vim.api.nvim_buf_get_name(data.buf), ":t") or "")
      ctx.preview:set_buf(data.buf)
      local pos = data.pos or { 1, 0 }
      local line_count = vim.api.nvim_buf_line_count(data.buf)
      pos = { math.min(math.max(pos[1] or 1, 1), math.max(line_count, 1)), math.max(pos[2] or 0, 0) }
      pcall(vim.api.nvim_win_set_cursor, ctx.preview.win.win, pos)
    end or nil,
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

  -- merge custom picker options
  if opts.snacks then
    picker_opts = Snacks.config.merge({}, vim.deepcopy(picker_opts), opts.snacks)
  end

  -- get full picker config
  picker_opts = Snacks.picker.config.get(picker_opts)

  -- merge kind options
  local kind_opts = picker_opts.kinds and picker_opts.kinds[opts.kind]
  if kind_opts then
    picker_opts = Snacks.config.merge({}, picker_opts, kind_opts)
  end

  return Snacks.picker.pick(picker_opts)
end

return M
