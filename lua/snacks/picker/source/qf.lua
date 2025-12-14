local M = {}

---Represents an item in a Neovim quickfix/loclist.
---@class qf.item
---@field bufnr? number The buffer number where the item originates.
---@field filename? string
---@field lnum number The start line number for the item.
---@field end_lnum? number The end line number for the item.
---@field pattern string A pattern related to the item. It can be a search pattern or any relevant string.
---@field col? number The column number where the item starts.
---@field end_col? number The column number where the item ends.
---@field module? string Module information (if any) associated with the item.
---@field nr? number A unique number or ID for the item.
---@field text? string A description or message related to the item.
---@field type? string The type of the item. E.g., "W" might stand for "Warning".
---@field valid number A flag indicating if the item is valid (1) or not (0).
---@field user_data? any Any user data associated with the item.
---@field vcol? number Visual column number. Indicates if the column number is a visual column number (when set to 1) or a byte index (when set to 0).

---@class snacks.picker.qf.Config
---@field qf_win? number
---@field filter? snacks.picker.filter.Config

local severities = {
  E = vim.diagnostic.severity.ERROR,
  W = vim.diagnostic.severity.WARN,
  I = vim.diagnostic.severity.INFO,
  H = vim.diagnostic.severity.HINT,
  N = vim.diagnostic.severity.HINT,
}

---@param opts snacks.picker.qf.Config
---@type snacks.picker.finder
function M.qf(opts, ctx)
  local win = opts.qf_win
  win = win == 0 and vim.api.nvim_get_current_win() or win

  local list = win and vim.fn.getloclist(win, { all = true }) or vim.fn.getqflist({ all = true })
  ---@cast list { items?: qf.item[] }?

  local ret = {} ---@type snacks.picker.finder.Item[]

  for _, item in pairs(list and list.items or {}) do
    local row = item.lnum == 0 and 1 or item.lnum
    local col = (item.col == 0 and 1 or item.col) - 1
    local end_row = item.end_lnum == 0 and row or item.end_lnum
    local end_col = item.end_col == 0 and col or (item.end_col - 1)

    if item.valid == 1 then
      local file = item.filename or item.bufnr and vim.api.nvim_buf_get_name(item.bufnr) or nil
      local text = item.text or ""
      ret[#ret + 1] = {
        pos = { row, col },
        end_pos = item.end_lnum ~= 0 and { end_row, end_col } or nil,
        text = file .. " " .. text,
        line = text,
        file = file,
        severity = severities[item.type] or 0,
        buf = item.bufnr,
        item = item,
      }
    elseif #ret > 0 and ret[#ret].text and item.text then
      ret[#ret].text = ret[#ret].text .. "\n" .. item.text
      ret[#ret].line = ret[#ret].line .. "\n" .. item.text
    end
  end
  return ctx.filter:filter(ret)
end

return M
