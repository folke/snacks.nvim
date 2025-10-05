-- Lualine component for snacks.nvim explorer breadcrumb
--
-- Shows the current file/directory path when the explorer window has focus
--
-- ## Usage
--
-- Add "snacks_explorer" component to your lualine configuration:
--
--   require("lualine").setup({
--     sections = {
--       lualine_c = { "snacks_explorer" },
--     },
--   })
--
-- ## Options
--
-- - `path_type`: Which path to display (default: "relative")
--   - "relative": Path relative to explorer cwd
--   - "display": `~`-relative path
--   - "filename": Just the filename
--
--   { "snacks_explorer", path_type = "display" }
--
-- The component will automatically:
-- - Show the current file/directory path with an icon (󰈔 for files, 󰉋 for directories)
-- - Only appear when the explorer window has focus
-- - Update as you navigate through the explorer

local M = require("lualine.component"):extend()

function M:init(options)
  M.super.init(self, options)
  self.options = vim.tbl_extend("force", {
    path_type = "relative",
  }, options or {})
end

function M:update_status()
  if not _G.Snacks or not _G.Snacks.explorer or not _G.Snacks.explorer.current_path then
    return ""
  end

  local current_win = vim.api.nvim_get_current_win()
  local explorer_win = _G.Snacks.explorer.list_win

  if not explorer_win or not vim.api.nvim_win_is_valid(explorer_win) or current_win ~= explorer_win then
    return ""
  end

  local path_info = _G.Snacks.explorer.current_path
  local icon = path_info.is_dir and "󰉋 " or "󰈔 "
  
  local path
  if self.options.path_type == "display" then
    path = path_info.display_path
  elseif self.options.path_type == "filename" then
    path = path_info.filename
  else
    path = path_info.relative_path
  end
  
  return icon .. " " .. path
end

return M
