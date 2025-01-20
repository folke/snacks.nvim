---@class snacks.picker.main
local M = {}

---@class snacks.picker.main.Config
---@field float? boolean main window can be a floating window (defaults to false)
---@field file? boolean main window should be a file (defaults to true)
---@field current? boolean main window should be the current window (defaults to false)

---@param opts? snacks.picker.main.Config
function M.get(opts)
  opts = vim.tbl_extend("force", {
    float = false,
    file = true,
    current = false,
  }, opts or {})
  local current = vim.api.nvim_get_current_win()
  if opts.current then
    return current
  end
  local prev = vim.fn.winnr("#")
  local wins = { current, prev }
  local all = vim.api.nvim_list_wins()
  -- sort all by lastused of the win buffer
  table.sort(all, function(a, b)
    local ba = vim.api.nvim_win_get_buf(a)
    local bb = vim.api.nvim_win_get_buf(b)
    return vim.fn.getbufinfo(ba)[1].lastused > vim.fn.getbufinfo(bb)[1].lastused
  end)
  vim.list_extend(wins, all)
  wins = vim.tbl_filter(function(win)
    -- exclude invalid windows
    if win == 0 or not vim.api.nvim_win_is_valid(win) then
      return false
    end
    -- exclude non-file buffers
    if opts.file and vim.bo[vim.api.nvim_win_get_buf(win)].buftype ~= "" then
      return false
    end
    local win_config = vim.api.nvim_win_get_config(win)
    local is_float = win_config.relative ~= ""
    -- exclude floating windows and non-focusable windows
    if is_float and (not opts.float or not win_config.focusable) then
      return false
    end
    return true
  end, wins)
  return wins[1] or current
end

return M
