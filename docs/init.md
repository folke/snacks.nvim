# 🍿 init

<!-- docgen -->

## 📦 Setup

```lua
-- lazy.nvim
{
  "folke/snacks.nvim",
  opts = {
    init = {
      -- your init configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    }
  }
}
```

## ⚙️ Config

```lua
---@class snacks.Config
---@field animate? snacks.animate.Config
---@field bigfile? snacks.bigfile.Config
---@field dashboard? snacks.dashboard.Config
---@field dim? snacks.dim.Config
---@field gitbrowse? snacks.gitbrowse.Config
---@field indent? snacks.indent.Config
---@field lazygit? snacks.lazygit.Config
---@field notifier? snacks.notifier.Config
---@field profiler? snacks.profiler.Config
---@field quickfile? snacks.quickfile.Config
---@field scope? snacks.scope.Config
---@field scratch? snacks.scratch.Config
---@field statuscolumn? snacks.statuscolumn.Config
---@field terminal? snacks.terminal.Config
---@field toggle? snacks.toggle.Config
---@field win? snacks.win.Config
---@field words? snacks.words.Config
---@field zen? snacks.zen.Config
---@field styles? table<string, snacks.win.Config>
{
  bigfile = { enabled = false },
  dashboard = { enabled = false },
  indent = { enabled = false },
  notifier = { enabled = false },
  quickfile = { enabled = false },
  statuscolumn = { enabled = false },
  styles = {},
  words = { enabled = false },
}
```

## 📚 Types

```lua
---@class snacks.Config.base
---@field example? string
---@field config? fun(opts: table, defaults: table)
```

## 📦 Module

### `Snacks.config.example()`

Get an example config from the docs/examples directory.

```lua
---@param snack string
---@param name string
---@param opts? table
Snacks.config.example(snack, name, opts)
```

### `Snacks.config.get()`

```lua
---@generic T: table
---@param snack string
---@param defaults T
---@param ... T[]
---@return T
Snacks.config.get(snack, defaults, ...)
```

### `Snacks.config.style()`

Register a new window style config.

```lua
---@param name string
---@param defaults snacks.win.Config
Snacks.config.style(name, defaults)
```

### `Snacks.setup()`

```lua
---@param opts snacks.Config?
Snacks.setup(opts)
```
