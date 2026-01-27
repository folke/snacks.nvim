# 🍿 scope

Scope detection based on treesitter or indent.

The indent-based algorithm is similar to what is used
in [mini.indentscope](https://github.com/nvim-mini/mini.indentscope).

<!-- docgen -->

## 📦 Setup

```lua
-- lazy.nvim
{
  "folke/snacks.nvim",
  ---@type snacks.Config
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
---@field enabled? boolean
{
  -- absolute minimum size of the scope.
  -- can be less if the scope is a top-level single line scope
  min_size = 2,
  -- try to expand the scope to this size
  max_size = nil,
  cursor = true, -- when true, the column of the cursor is used to determine the scope
  edge = true, -- include the edge of the scope (typically the line above and below with smaller indent)
  siblings = false, -- expand single line scopes with single line siblings
  -- what buffers to attach to
  filter = function(buf)
    return vim.bo[buf].buftype == "" and vim.b[buf].snacks_scope ~= false and vim.g.snacks_scope ~= false
  end,
  -- debounce scope detection in ms
  debounce = 30,
  treesitter = {
    -- detect scope based on treesitter.
    -- falls back to indent based detection if not available
    enabled = true,
    injections = true, -- include language injections when detecting scope (useful for languages like `vue`)
    ---@type string[]|{enabled?:boolean}
    blocks = {
      enabled = false, -- enable to use the following blocks
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
    -- these treesitter fields will be considered as blocks
    field_blocks = {
      "local_declaration",
    },
  },
  -- These keymaps will only be set if the `scope` plugin is enabled.
  -- Alternatively, you can set them manually in your config,
  -- using the `Snacks.scope.textobject` and `Snacks.scope.jump` functions.
  keys = {
    ---@type table<string, snacks.scope.TextObject|{desc?:string}|false>
    textobject = {
      ii = {
        min_size = 2, -- minimum size of the scope
        edge = false, -- inner scope
        cursor = false,
        treesitter = { blocks = { enabled = false } },
        desc = "inner scope",
      },
      ai = {
        cursor = false,
        min_size = 2, -- minimum size of the scope
        treesitter = { blocks = { enabled = false } },
        desc = "full scope",
      },
    },
    ---@type table<string, snacks.scope.Jump|{desc?:string}|false>
    jump = {
      ["[i"] = {
        min_size = 1, -- allow single line scopes
        bottom = false,
        cursor = false,
        edge = true,
        treesitter = { blocks = { enabled = false } },
        desc = "jump to top edge of scope",
      },
      ["]i"] = {
        min_size = 1, -- allow single line scopes
        bottom = true,
        cursor = false,
        edge = true,
        treesitter = { blocks = { enabled = false } },
        desc = "jump to bottom edge of scope",
      },
    },
  },
}
```

## 📚 Types

```lua
---@class snacks.scope.Opts: snacks.scope.Config,{}
---@field buf? number
---@field pos? {[1]:number, [2]:number} -- (1,0) indexed
---@field end_pos? {[1]:number, [2]:number} -- (1,0) indexed
---@field async? boolean run scope detection asynchronously (defaults to true)
```

```lua
---@class snacks.scope.TextObject: snacks.scope.Opts
---@field linewise? boolean if nil, use visual mode. Defaults to `false` when not in visual mode
---@field notify? boolean show a notification when no scope is found (defaults to true)
```

```lua
---@class snacks.scope.Jump: snacks.scope.Opts
---@field bottom? boolean if true, jump to the bottom of the scope, otherwise to the top
---@field notify? boolean show a notification when no scope is found (defaults to true)
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
---@param cb fun(scope?: snacks.scope.Scope)
---@param opts? snacks.scope.Opts|{parse?:boolean}
Snacks.scope.get(cb, opts)
```

### `Snacks.scope.jump()`

Jump to the top or bottom of the scope
If the scope is the same as the current scope, it will jump to the parent scope instead.

```lua
---@param opts? snacks.scope.Jump
Snacks.scope.jump(opts)
```

### `Snacks.scope.textobject()`

Text objects for indent scopes.
Best to use with Treesitter disabled.
When in visual mode, it will select the scope containing the visual selection.
When the scope is the same as the visual selection, it will select the parent scope instead.

```lua
---@param opts? snacks.scope.TextObject
Snacks.scope.textobject(opts)
```
