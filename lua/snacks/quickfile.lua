---@private
---@class snacks.quickfile
local M = {}

M.meta = {
  desc = "When doing `nvim somefile.txt`, it will render the file as quickly as possible, before loading your plugins.",
  needs_setup = true,
}

---@class snacks.quickfile.Config
local defaults = {
  -- any treesitter langs to exclude
  exclude = { "latex" },
}

---@private
function M.setup()
  local opts = Snacks.config.get("quickfile", defaults)
  -- Skip if we already entered vim
  if vim.v.vim_did_enter == 1 then
    return
  end
  if vim.bo.filetype == "bigfile" then
    return
  end

  local buf = vim.api.nvim_get_current_buf()

  -- Try to guess the filetype (may change later on during Neovim startup)
  local ft = vim.filetype.match({ buf = buf })
  if ft then
    -- Add treesitter highlights and fallback to syntax
    local lang = vim.treesitter.language.get_lang(ft)

    -- disable treesitter for some langs
    if vim.tbl_contains(opts.exclude, lang) then
      lang = nil
    end

    if not (lang and pcall(vim.treesitter.start, buf, lang)) then
      vim.bo[buf].syntax = ft
    end

    -- Trigger early redraw
    vim.cmd([[redraw]])
  end
end

return M
