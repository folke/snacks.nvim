---@class snacks.picker.Main
---@field opts snacks.picker.main.Config
---@field win number
local M = {}
M.__index = M

---@class snacks.picker.main.Config
---@field float? boolean main window can be a floating window (defaults to false)
---@field file? boolean main window should be a file (defaults to true)
---@field current? boolean main window should be the current window (defaults to false)

---@param opts? snacks.picker.main.Config
function M.new(opts)
  opts = vim.tbl_extend("force", {
    float = false,
    file = true,
    current = false,
  }, opts or {})
  local self = setmetatable({}, M)
  self.opts = opts
  self.win = vim.api.nvim_get_current_win()
  self.win = self:find()
  return self
end

function M:get()
  if not self.win or not vim.api.nvim_win_is_valid(self.win) then
    self.win = self:find()
  end
  return self.win
end

---@param win number
function M:set(win)
  self.win = win
end

function M:find()
  local current = vim.api.nvim_get_current_win()
  if self.opts.current then
    return current
  end
  local prev = vim.fn.win_getid(vim.fn.winnr("#"))
  local non_float = 0
  local wins = { self.win, current, prev }
  local all = vim.api.nvim_tabpage_list_wins(0)
  -- sort all by lastused of the win buffer
  table.sort(all, function(a, b)
    local ba = vim.api.nvim_win_get_buf(a)
    local bb = vim.api.nvim_win_get_buf(b)
    return vim.fn.getbufinfo(ba)[1].lastused > vim.fn.getbufinfo(bb)[1].lastused
  end)
  vim.list_extend(wins, all)
  ---@param win number
  wins = vim.tbl_filter(function(win)
    -- exclude invalid windows
    if win == 0 or not vim.api.nvim_win_is_valid(win) then
      return false
    end
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.w[win].snacks_main or vim.b[buf].snacks_main then
      return true
    end
    local win_config = vim.api.nvim_win_get_config(win)
    local is_float = win_config.relative ~= ""
    if not is_float then
      non_float = win
    end
    if vim.w[win].snacks_layout then
      return false
    end
    -- exclude non-file buffers
    if self.opts.file and vim.bo[buf].buftype ~= "" then
      return false
    end
    -- exclude floating windows and non-focusable windows
    if is_float and (not self.opts.float or not win_config.focusable) then
      return false
    end
    return true
  end, wins)
  return wins[1] or non_float
end

return M
