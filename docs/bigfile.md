# 🍿 bigfile

`bigfile` adds a new filetype `bigfile` to Neovim that triggers when the file is
larger than the configured size. This automatically prevents things like LSP
and Treesitter attaching to the buffer.

Use the `setup` config function to further make changes to a `bigfile` buffer.
The context provides the actual filetype.

The default implementation enables `syntax` for the buffer and disables
[mini.animate](https://github.com/nvim-mini/mini.animate) (if used)

<!-- docgen -->

## 📦 Setup

```lua
-- lazy.nvim
{
  "folke/snacks.nvim",
  ---@type snacks.Config
  opts = {
    bigfile = {
      -- your bigfile configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    }
  }
}
```

## ⚙️ Config

```lua
---@class snacks.bigfile.Config
---@field enabled? boolean
{
  notify = true, -- show notification when big file detected
  size = 1.5 * 1024 * 1024, -- 1.5MB
  line_length = 1000, -- average line length (useful for minified files)
  -- Enable or disable features when big file detected
  ---@param ctx {buf: number, ft:string}
  setup = function(ctx)
    if vim.fn.exists(":NoMatchParen") ~= 0 then
      vim.cmd([[NoMatchParen]])
    end
    Snacks.util.wo(0, { foldmethod = "manual", statuscolumn = "", conceallevel = 0 })
    vim.b.completion = false
    vim.b.minianimate_disable = true
    vim.b.minihipatterns_disable = true
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(ctx.buf) then
        vim.bo[ctx.buf].syntax = ctx.ft
      end
    end)
  end,
}
```
