# 🍿 layout

<!-- docgen -->

## 📦 Setup

```lua
-- lazy.nvim
{
  "folke/snacks.nvim",
  ---@type snacks.Config
  opts = {
    layout = {
      -- your layout configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    }
  }
}
```

## ⚙️ Config

```lua
---@class snacks.layout.Config
---@field show? boolean show the layout on creation (default: true)
---@field wins table<string, snacks.win> windows to include in the layout
---@field layout snacks.layout.Box layout definition
---@field fullscreen? boolean open in fullscreen
---@field hidden? string[] list of windows that will be excluded from the layout (but can be toggled)
---@field on_update? fun(layout: snacks.layout)
---@field on_update_pre? fun(layout: snacks.layout)
---@field on_close? fun(layout: snacks.layout)
{
  layout = {
    width = 0.6,
    height = 0.6,
    zindex = 50,
  },
}
```

## 📚 Types

```lua
---@class snacks.layout.Win: snacks.win.Config,{}
---@field depth? number
---@field win string layout window name
```

```lua
---@class snacks.layout.Box: snacks.layout.Win,{}
---@field box "horizontal" | "vertical"
---@field id? number
---@field [number] snacks.layout.Win | snacks.layout.Box children
```

```lua
---@alias snacks.layout.Widget snacks.layout.Win | snacks.layout.Box
```

## 📦 Module

```lua
---@class snacks.layout
---@field opts snacks.layout.Config
---@field root snacks.win
---@field wins table<string, snacks.win|{enabled?:boolean, layout?:boolean}>
---@field box_wins snacks.win[]
---@field win_opts table<string, snacks.win.Config>
---@field closed? boolean
---@field split? boolean
---@field screenpos number[]?
Snacks.layout = {}
```

### `Snacks.layout.new()`

```lua
---@param opts snacks.layout.Config
Snacks.layout.new(opts)
```

### `layout:close()`

Close the layout

```lua
---@param opts? {wins?: boolean}
layout:close(opts)
```

### `layout:each()`

```lua
---@param cb fun(widget: snacks.layout.Widget, parent?: snacks.layout.Box)
---@param opts? {wins?:boolean, boxes?:boolean, box?:snacks.layout.Box}
layout:each(cb, opts)
```

### `layout:hide()`

```lua
layout:hide()
```

### `layout:is_enabled()`

Check if the window has been used in the layout

```lua
---@param w string
layout:is_enabled(w)
```

### `layout:is_hidden()`

Check if a window is hidden

```lua
---@param win string
layout:is_hidden(win)
```

### `layout:maximize()`

Toggle fullscreen

```lua
layout:maximize()
```

### `layout:needs_layout()`

```lua
---@param win string
layout:needs_layout(win)
```

### `layout:show()`

Show the layout

```lua
layout:show()
```

### `layout:toggle()`

Toggle a window

```lua
---@param win string
---@param enable? boolean
---@param on_update? fun(enabled: boolean) called when the layout will be updated
layout:toggle(win, enable, on_update)
```

### `layout:unhide()`

```lua
layout:unhide()
```

### `layout:valid()`

Check if layout is valid (visible)

```lua
layout:valid()
```
