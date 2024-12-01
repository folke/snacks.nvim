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
---@param opts? { prefix?:string, default?:boolean, managed?:boolean }
function M.set_hl(groups, opts)
  for hl_group, hl in pairs(groups) do
    hl_group = opts and opts.prefix and opts.prefix .. hl_group or hl_group
    hl = type(hl) == "string" and { link = hl } or hl --[[@as vim.api.keyset.highlight]]
    hl.default = not (opts and opts.default == false)
    if not (opts and opts.managed == false) then
      hl_groups[hl_group] = hl
    end
    vim.api.nvim_set_hl(0, hl_group, hl)
  end
end

---@param group string
---@param prop? string
function M.color(group, prop)
  prop = prop or "fg"
  local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
  return hl[prop] and string.format("#%06x", hl[prop])
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

---@param name string
---@param cat? string
---@return string, string?
function M.icon(name, cat)
  local try = {
    function()
      return require("mini.icons").get(cat or "file", name)
    end,
    function()
      local Icons = require("nvim-web-devicons")
      if cat == "filetype" then
        return Icons.get_icon_by_filetype(name, { default = false })
      elseif cat == "file" then
        local ext = name:match("%.(%w+)$")
        return Icons.get_icon(name, ext, { default = false }) --[[@as string, string]]
      elseif cat == "extension" then
        return Icons.get_icon(nil, name, { default = false }) --[[@as string, string]]
      end
    end,
  }
  for _, fn in ipairs(try) do
    local ret = { pcall(fn) }
    if ret[1] and ret[2] then
      return ret[2], ret[3]
    end
  end
  return " "
end

-- Encodes a string to be used as a file name.
---@param str string
function M.file_encode(str)
  return str:gsub("([^%w%-_%.\t ])", function(c)
    return string.format("_%%%02X", string.byte(c))
  end)
end

-- Decodes a file name to a string.
---@param str string
function M.file_decode(str)
  return str:gsub("_%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end)
end

return M
