# 🍿 scope

<!-- docgen -->

## 📦 Setup

```lua
-- lazy.nvim
{
  "folke/snacks.nvim",
  opts = {
    scope = {
      -- your scope configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    }
  }
}
```

## ⚙️ Config

```lua
---@class snacks.scope.Config
---@field max_size? number
{
  -- absolute minimum size of the scope.
  -- can be less if the scope is a top-level single line scope
  min_size = 2,
  -- try to expand the scope to this size
  max_size = nil,
  siblings = false, -- expand single line scopes with single line siblings
  -- what buffers to attach to
  enabled = function(buf)
    return vim.bo[buf].buftype == ""
  end,
  -- debounce scope detection in ms
  debounce = 30,
  treesitter = {
    -- detect scope based on treesitter.
    -- falls back to indent based detection if not available
    enabled = true,
    ---@type string[]|false
    blocks = {
      "function_declaration",
      "function_definition",
      "method_declaration",
      "method_definition",
      "class_declaration",
      "class_definition",
      "do_statement",
      "while_statement",
      "repeat_statement",
      "if_statement",
      "for_statement",
    },
  },
}
```

## 📚 Types

```lua
---@class snacks.scope.Opts: snacks.scope.Config
---@field buf number
---@field pos {[1]:number, [2]:number} -- (1,0) indexed
```

```lua
---@alias snacks.scope.Attach.cb fun(win: number, buf: number, scope:snacks.scope.Scope?, prev:snacks.scope.Scope?)
```

```lua
---@alias snacks.scope.scope {buf: number, from: number, to: number, indent?: number}
```

## 📦 Module

### `Snacks.scope.attach()`

Attach a scope listener

```lua
---@param cb snacks.scope.Attach.cb
---@param opts? snacks.scope.Config
---@return snacks.scope.Listener
Snacks.scope.attach(cb, opts)
```

### `Snacks.scope.get()`

```lua
---@param opts? snacks.scope.Opts
---@return snacks.scope.Scope?
Snacks.scope.get(opts)
```
