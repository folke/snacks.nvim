local M = {}

local ns = vim.api.nvim_create_namespace("snacks.picker.util.markdown")
local did_setup = false

---@private
local function setup()
  if did_setup then
    return
  end
  did_setup = true

  -- trigger plugin loading if available
  pcall(require, "render-markdown")
  pcall(require, "markview")
end

---@param buf number
---@param opts? {images: boolean, bullets?: boolean}
function M.render(buf, opts)
  setup()
  opts = opts or {}

  local ft = vim.bo[buf].filetype
  if not ft:find("^markdown") then
    ft = ft:gsub("%.?markdown%.?", "")
    -- set filetype to markdown but preserve existing ft as a suffix
    -- use eventignore to avoid triggering autocmds
    local ei = vim.o.eventignore
    vim.o.eventignore = "all"
    vim.bo[buf].filetype = table.concat({ "markdown", ft ~= "" and ft or "" }, ".")
    vim.o.eventignore = ei
  end

  if not pcall(vim.treesitter.start, buf, "markdown") then
    vim.bo[buf].syntax = "markdown"
  end

  if opts.images ~= false then
    vim.b[buf].snacks_image_conceal = true
    Snacks.image.doc.attach(buf)
  end

  if package.loaded["render-markdown"] then
    require("render-markdown").render({
      buf = buf,
      event = "Snacks",
      config = {
        render_modes = true,
        bullet = { enabled = opts.bullets ~= false },
      },
    })
  elseif package.loaded["markview"] then
    local render = require("markview").strict_render
    render:render(buf, nil, {
      markdown = {
        list_items = {
          enable = opts.bullets ~= false,
        },
      },
    })
  else
    M.render_fallback(buf)
  end
end

-- Fallback simple highlighting for headings and horizontal rules
---@param buf number
function M.render_fallback(buf)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  for l, line in ipairs(lines) do
    local _, level = line:find("^#+()")
    if level then
      vim.api.nvim_buf_set_extmark(buf, ns, l - 1, 0, {
        line_hl_group = "@markup.heading." .. tostring(level) .. ".markdown",
      })
    elseif line:find("^%-%-%-+%s*$") then
      vim.api.nvim_buf_set_extmark(buf, ns, l - 1, 0, {
        virt_text_win_col = 0,
        virt_text = { { string.rep("-", vim.go.columns), "SnacksPickerRule" } },
        priority = 100,
      })
    end
  end
end

return M
