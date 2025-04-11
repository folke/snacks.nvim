# 🍿 health

<!-- docgen -->

## 📚 Types

```lua
---@class snacks.health.Tool
---@field cmd string|string[]
---@field version? string|false
---@field enabled? boolean
```

```lua
---@alias snacks.health.Tool.spec (string|snacks.health.Tool)[]|snacks.health.Tool|string
```

## 📦 Module

```lua
---@class snacks.health
---@field ok fun(msg: string)
---@field warn fun(msg: string)
---@field error fun(msg: string)
---@field info fun(msg: string)
---@field start fun(msg: string)
Snacks.health = {}
```

### `Snacks.health.check()`

```lua
Snacks.health.check()
```

### `Snacks.health.has_lang()`

Check if the given languages are available in treesitter

```lua
---@param langs string[]|string
Snacks.health.has_lang(langs)
```

### `Snacks.health.have_tool()`

Check if any of the tools are available, with an optional version check

```lua
---@param tools snacks.health.Tool.spec
Snacks.health.have_tool(tools)
```
