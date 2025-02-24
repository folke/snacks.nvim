# 🍿 explorer

A file explorer for snacks. This is actually a [picker](https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#explorer) in disguise.

This module provide a shortcut to open the explorer picker and
a setup function to replace netrw with the explorer.

When the explorer and `replace_netrw` is enabled, the explorer will be opened:

- when you start `nvim` with a directory
- when you open a directory in vim

Configuring the explorer picker is done with the [picker options](https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#explorer).

```lua
-- lazy.nvim
{
  "folke/snacks.nvim",
  ---@type snacks.Config
  opts = {
    explorer = {
      -- your explorer configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    },
    picker = {
      sources = {
        explorer = {
          -- your explorer picker configuration comes here
          -- or leave it empty to use the default settings
        }
      }
    }
  }
}
```

![image](https://github.com/user-attachments/assets/e09d25f8-8559-441c-a0f7-576d2aa57097)

<!-- docgen -->

## 📦 Setup

```lua
-- lazy.nvim
{
  "folke/snacks.nvim",
  ---@type snacks.Config
  opts = {
    explorer = {
      -- your explorer configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    }
  }
}
```

## ⚙️ Config

These are just the general explorer settings.
To configure the explorer picker, see `snacks.picker.explorer.Config`

```lua
---@class snacks.explorer.Config
{
  replace_netrw = true, -- Replace netrw with the snacks explorer
}
```

## 📦 Module

### `Snacks.explorer()`

```lua
---@type fun(opts?: snacks.picker.explorer.Config): snacks.Picker
Snacks.explorer()
```

### `Snacks.explorer.open()`

Shortcut to open the explorer picker

```lua
---@param opts? snacks.picker.explorer.Config|{}
Snacks.explorer.open(opts)
```

### `Snacks.explorer.reveal()`

Reveals the given file/buffer or the current buffer in the explorer

```lua
---@param opts? {file?:string, buf?:number}
Snacks.explorer.reveal(opts)
```
