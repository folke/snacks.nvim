local M = {}

---@class snacks.picker
---@field symbols fun(opts?: snacks.picker.symbols.Config): snacks.Picker

---@class snacks.picker.symbols.Config
---@field data string[]

---@param opts snacks.picker.symbols.Config
function M.symbols(opts)
  ---@async
  ---@param cb async fun(item: snacks.picker.finder.Item)
  return function(cb)
    ---@type string[]
    local files = vim.tbl_filter(function(file)
      return vim.tbl_contains(opts.data, vim.fn.fnamemodify(file, ":t:r"))
    end, vim.api.nvim_get_runtime_file("data/telescope-sources/*.json", true))

    for _, file in ipairs(files) do
      local fd = vim.uv.fs_open(file, "r", 438)
      if not fd then
        goto continue
      end
      local stat = assert(vim.uv.fs_fstat(fd))
      local data = assert(vim.uv.fs_read(fd, stat.size, 0))
      local items = vim.json.decode(data)
      for _, item in ipairs(items) do
        cb({
          text = item[1] .. " " .. item[2],
          symbol = item[1],
          desc = item[2],
        })
      end
      vim.uv.fs_close(fd)

      ::continue::
    end
  end
end

return M
