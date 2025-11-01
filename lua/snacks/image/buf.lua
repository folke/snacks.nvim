---@class snacks.image.buf
local M = {}

---@param buf number
---@param opts? snacks.image.Opts|{src?: string}
function M._attach(buf, opts)
  Snacks.image.placement.clean(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  opts = opts or {}
  local file = opts.src or vim.api.nvim_buf_get_name(buf)
  if not Snacks.image.supports(file) then
    local lines = {} ---@type string[]
    lines[#lines + 1] = "# Image viewer"
    lines[#lines + 1] = "- **file**: `" .. file .. "`"
    if not Snacks.image.supports_file(file) then
      lines[#lines + 1] = "- unsupported image format"
    end
    if not Snacks.image.supports_terminal() then
      lines[#lines + 1] = "- terminal does not support the kitty graphics protocol."
      lines[#lines + 1] = "  See `:checkhealth snacks` for more info."
    end
    vim.bo[buf].modifiable = true
    vim.bo[buf].filetype = "markdown"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(table.concat(lines, "\n"), "\n"))
    vim.bo[buf].modifiable = false
    vim.bo[buf].modified = false
  else
    Snacks.util.bo(buf, {
      filetype = "image",
      modifiable = false,
      modified = false,
      swapfile = false,
    })
    opts.conceal = true
    opts.auto_resize = true
    return Snacks.image.placement.new(buf, file, opts)
  end
end

---@param buf number
---@param opts? snacks.image.Opts|{src?: string}
function M.attach(buf, opts)
  local Terminal = require("snacks.image.terminal")
  Terminal.detect(function()
    M._attach(buf, opts)
  end)
end

return M
