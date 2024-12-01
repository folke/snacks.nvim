# 🍿 util

<!-- docgen -->

## 📚 Types

```lua
---@alias snacks.util.hl table<string, string|vim.api.keyset.highlight>
```

## 📦 Module

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
