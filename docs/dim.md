# 🍿 dim

Focus on the active scope by dimming the rest.

Similar plugins:

- [twilight.nvim](https://github.com/folke/twilight.nvim)
- [limelight.vim](https://github.com/junegunn/limelight.vim)
- [goyo.vim](https://github.com/junegunn/goyo.vim)

![image](https://github.com/user-attachments/assets/c0c5ffda-aaeb-4578-8a18-abee2e443a93)


<!-- docgen -->

## 📦 Setup

```lua
-- lazy.nvim
{
  "folke/snacks.nvim",
  ---@type snacks.Config
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
  -- what buffers to dim
  filter = function(buf)
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
