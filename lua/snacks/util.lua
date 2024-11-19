---@class snacks.util
local M = {}

---@alias snacks.util.hl table<string, string|vim.api.keyset.highlight>

local hl_groups = {} ---@type table<string, vim.api.keyset.highlight>
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("snacks_util_hl", { clear = true }),
  callback = function()
    for hl_group, hl in pairs(hl_groups) do
      vim.api.nvim_set_hl(0, hl_group, hl)
    end
  end,
})

--- Ensures the hl groups are always set, even after a colorscheme change.
---@param groups snacks.util.hl
---@param opts? { prefix?:string, default?:boolean }
function M.set_hl(groups, opts)
  for hl_group, hl in pairs(groups) do
    hl_group = opts and opts.prefix and opts.prefix .. hl_group or hl_group
    hl = type(hl) == "string" and { link = hl } or hl --[[@as vim.api.keyset.highlight]]
    hl.default = not (opts and opts.default == false)
    hl_groups[hl_group] = hl
    vim.api.nvim_set_hl(0, hl_group, hl)
  end
end

---@param win number
---@param wo vim.wo
function M.wo(win, wo)
  for k, v in pairs(wo or {}) do
    vim.api.nvim_set_option_value(k, v, { scope = "local", win = win })
  end
end

---@param buf number
---@param bo vim.bo
function M.bo(buf, bo)
  for k, v in pairs(bo or {}) do
    vim.api.nvim_set_option_value(k, v, { buf = buf })
  end
end

return M
