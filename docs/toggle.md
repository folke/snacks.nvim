# 🍿 toggle

Toggle keymaps integrated with which-key icons / colors

![image](https://github.com/user-attachments/assets/6d843acd-1ac1-44fd-b318-58b4c17de2d5)

<!-- docgen -->

## ⚙️ Config

```lua
---@class snacks.toggle.Config
---@field icon? string|{ enabled: string, disabled: string }
---@field color? string|{ enabled: string, disabled: string }
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
}
```

## 📚 Types

```lua
---@class snacks.toggle.Opts: snacks.toggle.Config
---@field name string
---@field get fun():boolean
---@field set fun(state:boolean)
```

## 📦 Module

```lua
---@class snacks.toggle
---@field opts snacks.toggle.Opts
Snacks.toggle = {}
```

### `Snacks.toggle()`

```lua
---@type fun(... :snacks.toggle.Opts): snacks.toggle
Snacks.toggle()
```

### `Snacks.toggle.diagnostics()`

```lua
---@param opts? snacks.toggle.Config
Snacks.toggle.diagnostics(opts)
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
---@return snacks.toggle
Snacks.toggle.new(...)
```

### `Snacks.toggle.option()`

```lua
---@param option string
---@param opts? snacks.toggle.Config | {on?: unknown, off?: unknown}
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

### `Snacks.toggle.treesitter()`

```lua
---@param opts? snacks.toggle.Config
Snacks.toggle.treesitter(opts)
```

### `toggle:get()`

```lua
toggle:get()
```

### `toggle:map()`

```lua
---@param keys string
---@param opts? vim.keymap.set.Opts | { mode: string|string[]}
toggle:map(keys, opts)
```

### `toggle:set()`

```lua
---@param state boolean
toggle:set(state)
```

### `toggle:toggle()`

```lua
toggle:toggle()
```
