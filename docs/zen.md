# 🍿 zen

Zen mode • distraction-free coding.
Integrates with `Snacks.toggle` to toggle various UI elements
and with `Snacks.dim` to dim code out of scope.

Similar plugins:

- [zen-mode.nvim](https://github.com/folke/zen-mode.nvim)
- [true-zen.nvim](https://github.com/pocco81/true-zen.nvim)

![image](https://github.com/user-attachments/assets/77c607ec-c354-4e17-bcd1-fdcd4b4c0057)

<!-- docgen -->

## 📦 Setup

```lua
-- lazy.nvim
{
  "folke/snacks.nvim",
  ---@type snacks.Config
  opts = {
    zen = {
      -- your zen configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    }
  }
}
```

## ⚙️ Config

```lua
---@class snacks.zen.Config
{
  -- You can add any `Snacks.toggle` id here.
  -- Toggle state is restored when the window is closed.
  -- Toggle config options are NOT merged.
  ---@type table<string, boolean>
  toggles = {
    dim = true,
    git_signs = false,
    mini_diff_signs = false,
    -- diagnostics = false,
    -- inlay_hints = false,
  },
  center = true, -- center the window
  show = {
    statusline = false, -- can only be shown when using the global statusline
    tabline = false,
  },
  ---@type snacks.win.Config
  win = { style = "zen" },
  --- Callback when the window is opened.
  ---@param win snacks.win
  on_open = function(win) end,
  --- Callback when the window is closed.
  ---@param win snacks.win
  on_close = function(win) end,
  --- Options for the `Snacks.zen.zoom()`
  ---@type snacks.zen.Config
  zoom = {
    toggles = {},
    center = false,
    show = { statusline = true, tabline = true },
    win = {
      backdrop = false,
      width = 0, -- full width
    },
  },
}
```

## 🎨 Styles

Check the [styles](https://github.com/folke/snacks.nvim/blob/main/docs/styles.md)
docs for more information on how to customize these styles

### `zen`

```lua
{
  enter = true,
  fixbuf = false,
  minimal = false,
  width = 120,
  height = 0,
  backdrop = { transparent = true, blend = 40 },
  keys = { q = false },
  zindex = 40,
  wo = {
    winhighlight = "NormalFloat:Normal",
  },
  w = {
    snacks_main = true,
  },
}
```

### `zoom_indicator`

fullscreen indicator
only shown when the window is maximized

```lua
{
  text = "▍ zoom  󰊓  ",
  minimal = true,
  enter = false,
  focusable = false,
  height = 1,
  row = 0,
  col = -1,
  backdrop = false,
}
```

## 📦 Module

### `Snacks.zen()`

```lua
---@type fun(opts: snacks.zen.Config): snacks.win
Snacks.zen()
```

### `Snacks.zen.zen()`

```lua
---@param opts? snacks.zen.Config
Snacks.zen.zen(opts)
```

### `Snacks.zen.zoom()`

```lua
---@param opts? snacks.zen.Config
Snacks.zen.zoom(opts)
```
