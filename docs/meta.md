# 🍿 meta

Meta functions for Snacks

<!-- docgen -->

## 📚 Types

```lua
---@class snacks.meta.Meta
---@field desc string
---@field needs_setup? boolean
---@field hide? boolean
---@field readme? boolean
---@field docs? boolean
---@field health? boolean
---@field types? boolean
---@field config? boolean
---@field merge? { [string|number]: string }
```

```lua
---@class snacks.meta.Plugin
---@field name string
---@field file string
---@field meta snacks.meta.Meta
---@field health? fun()
```

## 📦 Module

### `Snacks.meta.file()`

```lua
Snacks.meta.file(name)
```

### `Snacks.meta.get()`

Get the metadata for all snacks plugins

```lua
---@return snacks.meta.Plugin[]
Snacks.meta.get()
```
