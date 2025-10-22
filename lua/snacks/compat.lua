---@generic T
---@param t T
---@return T
local function wrap(t)
  return setmetatable({}, { __index = t })
end

local M = wrap(vim)

M.meta = {
  desc = "Neovim compatibility layer",
  hide = true,
}

local is_win = jit.os:find("Windows")

M.islist = vim.islist or vim.tbl_islist
M.uv = vim.uv or vim.loop

if vim.fn.has("nvim-0.11") == 0 then
  M.fs = wrap(vim.fs)

  ---@param path (string) Path to normalize
  ---@param opts? vim.fs.normalize.Opts
  ---@return (string) : Normalized path
  function M.fs.normalize(path, opts)
    local ret = vim.fs.normalize(path, opts)
    return is_win and ret:gsub("^%a:", string.upper) or ret
  end
end

return M
