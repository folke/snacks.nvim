local M = {}
local uv = vim.uv or vim.loop

---@param opts snacks.picker.diagnostics.Config
---@type snacks.picker.finder
function M.diagnostics(opts, ctx)
  local items = {} ---@type snacks.picker.finder.Item[]
  local current_buf = vim.api.nvim_get_current_buf()
  local cwd = svim.fs.normalize(uv.cwd() or ".")
  for _, diag in ipairs(vim.diagnostic.get(ctx.filter.buf, { severity = opts.severity })) do
    local buf = diag.bufnr
    if buf and vim.api.nvim_buf_is_valid(buf) then
      local file = svim.fs.normalize(vim.api.nvim_buf_get_name(buf), { _fast = true })
      local severity = diag.severity
      severity = type(severity) == "number" and vim.diagnostic.severity[severity] or severity
      ---@cast severity string?
      items[#items + 1] = {
        text = table.concat({ severity or "", tostring(diag.code or ""), file, diag.source or "", diag.message }, " "),
        file = file,
        buf = diag.bufnr,
        is_current = buf == current_buf and 0 or 1,
        is_cwd = file:sub(1, #cwd) == cwd and 0 or 1,
        lnum = diag.lnum,
        severity = diag.severity,
        pos = { diag.lnum + 1, diag.col },
        end_pos = diag.end_lnum and { diag.end_lnum + 1, diag.end_col } or nil,
        item = diag,
        comment = diag.message,
      }
    end
  end
  return ctx.filter:filter(items)
end

return M
