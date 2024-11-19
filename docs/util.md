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

### `Snacks.util.set_hl()`

Ensures the hl groups are always set, even after a colorscheme change.

```lua
---@param groups snacks.util.hl
---@param opts? { prefix?:string, default?:boolean }
Snacks.util.set_hl(groups, opts)
```

### `Snacks.util.wo()`

```lua
---@param win number
---@param wo vim.wo
Snacks.util.wo(win, wo)
```
