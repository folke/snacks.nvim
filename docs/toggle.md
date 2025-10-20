# 🍿 toggle

Toggle keymaps integrated with which-key icons / colors

![image](https://github.com/user-attachments/assets/6d843acd-1ac1-44fd-b318-58b4c17de2d5)

<!-- docgen -->

## 📦 Setup

```lua
-- lazy.nvim
{
  "folke/snacks.nvim",
  ---@type snacks.Config
  opts = {
    toggle = {
      -- your toggle configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    }
  }
}
```

## ⚙️ Config

```lua
---@class snacks.toggle.Config
---@field icon? string|{ enabled: string, disabled: string }
---@field color? string|{ enabled: string, disabled: string }
---@field wk_desc? string|{ enabled: string, disabled: string }
---@field map? fun(mode: string|string[], lhs: string, rhs: string|fun(), opts?: vim.keymap.set.Opts)
---@field which_key? boolean
---@field notify? boolean
{
  map = vim.keymap.set, -- keymap.set function to use
  which_key = true, -- integrate with which-key to show enabled/disabled icons and colors
  notify = true, -- show a notification when toggling
  -- icons for enabled/disabled states
  icon = {
    enabled = " ",
    disabled = " ",
  },
  -- colors for enabled/disabled states
  color = {
    enabled = "green",
    disabled = "yellow",
  },
  wk_desc = {
    enabled = "Disable ",
    disabled = "Enable ",
  },
}
```

## 📚 Types

```lua
---@class snacks.toggle.Opts: snacks.toggle.Config
---@field id? string
---@field name string
---@field get fun():boolean
---@field set fun(state:boolean)
```

## 📦 Module

### `Snacks.toggle()`

```lua
---@type fun(... :snacks.toggle.Opts): snacks.toggle.Class
Snacks.toggle()
```

### `Snacks.toggle.animate()`

```lua
Snacks.toggle.animate()
```

### `Snacks.toggle.diagnostics()`

```lua
---@param opts? snacks.toggle.Config
Snacks.toggle.diagnostics(opts)
```

### `Snacks.toggle.dim()`

```lua
Snacks.toggle.dim()
```

### `Snacks.toggle.get()`

```lua
---@param id string
---@return snacks.toggle.Class?
Snacks.toggle.get(id)
```

### `Snacks.toggle.indent()`

```lua
Snacks.toggle.indent()
```

### `Snacks.toggle.inlay_hints()`

```lua
---@param opts? snacks.toggle.Config
Snacks.toggle.inlay_hints(opts)
```

### `Snacks.toggle.line_number()`

```lua
---@param opts? snacks.toggle.Config
Snacks.toggle.line_number(opts)
```

### `Snacks.toggle.new()`

```lua
---@param ... snacks.toggle.Opts
Snacks.toggle.new(...)
```

### `Snacks.toggle.option()`

```lua
---@param option string
---@param opts? snacks.toggle.Config | {on?: unknown, off?: unknown, global?: boolean}
Snacks.toggle.option(option, opts)
```

### `Snacks.toggle.profiler()`

```lua
Snacks.toggle.profiler()
```

### `Snacks.toggle.profiler_highlights()`

```lua
Snacks.toggle.profiler_highlights()
```

### `Snacks.toggle.scroll()`

```lua
Snacks.toggle.scroll()
```

### `Snacks.toggle.treesitter()`

```lua
---@param opts? snacks.toggle.Config
Snacks.toggle.treesitter(opts)
```

### `Snacks.toggle.words()`

```lua
Snacks.toggle.words()
```

### `Snacks.toggle.zen()`

```lua
Snacks.toggle.zen()
```

### `Snacks.toggle.zoom()`

```lua
Snacks.toggle.zoom()
```
