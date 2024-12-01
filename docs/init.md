# 🍿 init

<!-- docgen -->

## ⚙️ Config

```lua
---@class snacks.Config
---@field bigfile? snacks.bigfile.Config | { enabled: boolean }
---@field gitbrowse? snacks.gitbrowse.Config
---@field lazygit? snacks.lazygit.Config
---@field notifier? snacks.notifier.Config | { enabled: boolean }
---@field quickfile? { enabled: boolean }
---@field statuscolumn? snacks.statuscolumn.Config  | { enabled: boolean }
---@field styles? table<string, snacks.win.Config>
---@field dashboard? snacks.dashboard.Config  | { enabled: boolean }
---@field terminal? snacks.terminal.Config
---@field toggle? snacks.toggle.Config
---@field win? snacks.win.Config
---@field words? snacks.words.Config
{
  styles = {},
  bigfile = { enabled = false },
  dashboard = { enabled = false },
  notifier = { enabled = false },
  quickfile = { enabled = false },
  statuscolumn = { enabled = false },
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

```lua
---@class Snacks
---@field bigfile snacks.bigfile
---@field bufdelete snacks.bufdelete
---@field config snacks.config
---@field dashboard snacks.dashboard
---@field debug snacks.debug
---@field git snacks.git
---@field gitbrowse snacks.gitbrowse
---@field lazygit snacks.lazygit
---@field notifier snacks.notifier
---@field notify snacks.notify
---@field quickfile snacks.quickfile
---@field health snacks.health
---@field profiler snacks.profiler
---@field rename snacks.rename
---@field scratch snacks.scratch
---@field statuscolumn snacks.statuscolumn
---@field terminal snacks.terminal
---@field toggle snacks.toggle
---@field util snacks.util
---@field win snacks.win
---@field words snacks.words
Snacks = {}
```

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
