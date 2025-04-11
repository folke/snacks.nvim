# 🍿 quickfile

When doing `nvim somefile.txt`, it will render the file as quickly as possible,
before loading your plugins.

<!-- docgen -->

## 📦 Setup

```lua
-- lazy.nvim
{
  "folke/snacks.nvim",
  ---@type snacks.Config
  opts = {
    quickfile = {
      -- your quickfile configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    }
  }
}
```

## ⚙️ Config

```lua
---@class snacks.quickfile.Config
{
  -- any treesitter langs to exclude
  exclude = { "latex" },
}
```
