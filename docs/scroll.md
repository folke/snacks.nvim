# 🍿 scroll

<!-- docgen -->

## 📦 Setup

```lua
-- lazy.nvim
{
  "folke/snacks.nvim",
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
---@field animate snacks.animate.Config
{
  animate = {
    duration = { step = 15, total = 250 },
    easing = "linear",
  },
  -- what buffers to animate
  filter = function(buf)
    return vim.g.snacks_scroll ~= false and vim.b[buf].snacks_scroll ~= false
  end,
}
```

## 📚 Types

```lua
---@alias snacks.scroll.View {topline:number, lnum:number}
```

```lua
---@class snacks.scroll.State
---@field win number
---@field buf number
---@field view snacks.scroll.View
---@field current snacks.scroll.View
---@field target snacks.scroll.View
---@field scrolloff number
---@field mousescroll number
---@field height number
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
