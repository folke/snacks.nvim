# 🍿 dim

<!-- docgen -->

## 📦 Setup

```lua
-- lazy.nvim
{
  "folke/snacks.nvim",
  opts = {
    dim = {
      -- your dim configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    }
  }
}
```

## ⚙️ Config

```lua
---@class snacks.dim.Config
{
  ---@type snacks.scope.Config
  scope = {
    min_size = 5,
    max_size = 20,
    siblings = true,
  },
  -- animate scopes. Enabled by default for Neovim >= 0.10
  -- Works on older versions but has to trigger redraws during animation.
  ---@type snacks.animate.Config|{enabled?: boolean}
  animate = {
    enabled = vim.fn.has("nvim-0.10") == 1,
    easing = "outQuad",
    duration = {
      step = 20, -- ms per step
      total = 300, -- maximum duration
    },
  },
  enabled = function(buf)
    return vim.g.snacks_dim ~= false and vim.b[buf].snacks_dim ~= false and vim.bo[buf].buftype == ""
  end,
}
```

## 📦 Module

### `Snacks.dim()`

```lua
---@type fun(opts: snacks.dim.Config)
Snacks.dim()
```

### `Snacks.dim.animate()`

Animate scope changes

```lua
Snacks.dim.animate()
```

### `Snacks.dim.disable()`

Disable dimming

```lua
Snacks.dim.disable()
```

### `Snacks.dim.enable()`

```lua
---@param opts? snacks.dim.Config
Snacks.dim.enable(opts)
```

### `Snacks.dim.on_win()`

Called during every redraw cycle, so it should be fast.
Everything that can be cached should be cached.

```lua
---@param win number
---@param buf number
---@param top number -- 1-indexed
---@param bottom number -- 1-indexed
Snacks.dim.on_win(win, buf, top, bottom)
```
