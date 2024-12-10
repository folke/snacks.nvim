# 🍿 util

<!-- docgen -->

## 📚 Types

```lua
---@alias snacks.util.hl table<string, string|vim.api.keyset.highlight>
```

## 📦 Module

### `Snacks.util.blend()`

```lua
---@param fg string foreground color
---@param bg string background color
---@param alpha number number between 0 and 1. 0 results in bg, 1 results in fg
Snacks.util.blend(fg, bg, alpha)
```

### `Snacks.util.bo()`

```lua
---@param buf number
---@param bo vim.bo
Snacks.util.bo(buf, bo)
```

### `Snacks.util.color()`

```lua
---@param group string
---@param prop? string
Snacks.util.color(group, prop)
```

### `Snacks.util.file_decode()`

Decodes a file name to a string.

```lua
---@param str string
Snacks.util.file_decode(str)
```

### `Snacks.util.file_encode()`

Encodes a string to be used as a file name.

```lua
---@param str string
Snacks.util.file_encode(str)
```

### `Snacks.util.icon()`

```lua
---@param name string
---@param cat? string
---@return string, string?
Snacks.util.icon(name, cat)
```

### `Snacks.util.is_transparent()`

```lua
Snacks.util.is_transparent()
```

### `Snacks.util.redraw()`

Redraw the window.
Optimized for Neovim >= 0.10

```lua
---@param win number
Snacks.util.redraw(win)
```

### `Snacks.util.redraw_range()`

Redraw the range of lines in the window.
Optimized for Neovim >= 0.10

```lua
---@param win number
---@param from number -- 1-indexed, inclusive
---@param to number -- 1-indexed, inclusive
Snacks.util.redraw_range(win, from, to)
```

### `Snacks.util.set_hl()`

Ensures the hl groups are always set, even after a colorscheme change.

```lua
---@param groups snacks.util.hl
---@param opts? { prefix?:string, default?:boolean, managed?:boolean }
Snacks.util.set_hl(groups, opts)
```

### `Snacks.util.wo()`

```lua
---@param win number
---@param wo vim.wo
Snacks.util.wo(win, wo)
```
