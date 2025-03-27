local M = {}

---@param opts snacks.picker.buffers.Config
---@type snacks.picker.finder
function M.buffers(opts, ctx)
  opts = vim.tbl_extend("force", {
    hidden = false,
    unloaded = true,
    current = true,
    nofile = false,
    sort_lastused = true,
  }, opts)
  local items = {} ---@type snacks.picker.finder.Item[]
  local current_buf = vim.api.nvim_get_current_buf()
  local alternate_buf = vim.fn.bufnr("#")
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local keep = (opts.hidden or vim.bo[buf].buflisted)
      and (opts.unloaded or vim.api.nvim_buf_is_loaded(buf))
      and (opts.current or buf ~= current_buf)
      and (opts.nofile or vim.bo[buf].buftype ~= "nofile")
      and (not opts.modified or vim.bo[buf].modified)
    if keep then
      local name = vim.api.nvim_buf_get_name(buf)
      if name == "" then
        name = "[No Name]" .. (vim.bo[buf].filetype ~= "" and " " .. vim.bo[buf].filetype or "")
      end
      local info = vim.fn.getbufinfo(buf)[1]
      local mark = vim.api.nvim_buf_get_mark(buf, '"')
      local flags = {
        buf == current_buf and "%" or (buf == alternate_buf and "#" or ""),
        info.hidden == 1 and "h" or (#(info.windows or {}) > 0) and "a" or "",
        vim.bo[buf].readonly and "=" or "",
        info.changed == 1 and "+" or "",
      }
      table.insert(items, {
        flags = table.concat(flags),
        buf = buf,
        text = buf .. " " .. name,
        file = name,
        info = info,
        pos = mark[1] ~= 0 and mark or { info.lnum, 0 },
      })
    end
  end
  if opts.sort_lastused then
    table.sort(items, function(a, b)
      return a.info.lastused > b.info.lastused
    end)
  end
  return ctx.filter:filter(items)
end

return M
