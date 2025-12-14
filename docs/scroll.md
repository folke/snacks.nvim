# 🍿 scroll

Smooth scrolling for Neovim.
Properly handles `scrolloff` and mouse scrolling.

Similar plugins:

- [mini.animate](https://github.com/nvim-mini/mini.animate)
- [neoscroll.nvim](https://github.com/karb94/neoscroll.nvim)

<!-- docgen -->

## 📦 Setup

```lua
-- lazy.nvim
{
  "folke/snacks.nvim",
  ---@type snacks.Config
  opts = {
    scroll = {
      -- your scroll configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    }
  }
}
```

## ⚙️ Config

```lua
---@class snacks.scroll.Config
---@field animate snacks.animate.Config|{}
---@field animate_repeat snacks.animate.Config|{}|{delay:number}
{
  animate = {
    duration = { step = 10, total = 200 },
    easing = "linear",
  },
  -- faster animation when repeating scroll after delay
  animate_repeat = {
    delay = 100, -- delay in ms before using the repeat animation
    duration = { step = 5, total = 50 },
    easing = "linear",
  },
  -- what buffers to animate
  filter = function(buf)
    return vim.g.snacks_scroll ~= false and vim.b[buf].snacks_scroll ~= false and vim.bo[buf].buftype ~= "terminal"
  end,
}
```

## 📚 Types

```lua
---@alias snacks.scroll.View {topline:number, lnum:number}
```

## 📦 Module

### `Snacks.scroll.disable()`

```lua
Snacks.scroll.disable()
```

### `Snacks.scroll.enable()`

```lua
Snacks.scroll.enable()
```
