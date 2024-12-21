# 🍿 init

<!-- docgen -->

## ⚙️ Config

```lua
---@class snacks.Config
---@field animate? snacks.animate.Config
---@field bigfile? snacks.bigfile.Config
---@field dashboard? snacks.dashboard.Config
---@field dim? snacks.dim.Config
---@field gitbrowse? snacks.gitbrowse.Config
---@field indent? snacks.indent.Config
---@field input? snacks.input.Config
---@field lazygit? snacks.lazygit.Config
---@field notifier? snacks.notifier.Config
---@field profiler? snacks.profiler.Config
---@field quickfile? snacks.quickfile.Config
---@field scope? snacks.scope.Config
---@field scratch? snacks.scratch.Config
---@field scroll? snacks.scroll.Config
---@field statuscolumn? snacks.statuscolumn.Config
---@field terminal? snacks.terminal.Config
---@field toggle? snacks.toggle.Config
---@field win? snacks.win.Config
---@field words? snacks.words.Config
---@field zen? snacks.zen.Config
---@field styles? table<string, snacks.win.Config>
{}
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
---@field animate snacks.animate
---@field bigfile snacks.bigfile
---@field bufdelete snacks.bufdelete
---@field dashboard snacks.dashboard
---@field debug snacks.debug
---@field dim snacks.dim
---@field git snacks.git
---@field gitbrowse snacks.gitbrowse
---@field health snacks.health
---@field indent snacks.indent
---@field input snacks.input
---@field lazygit snacks.lazygit
---@field meta snacks.meta
---@field notifier snacks.notifier
---@field notify snacks.notify
---@field profiler snacks.profiler
---@field quickfile snacks.quickfile
---@field rename snacks.rename
---@field scope snacks.scope
---@field scratch snacks.scratch
---@field scroll snacks.scroll
---@field statuscolumn snacks.statuscolumn
---@field terminal snacks.terminal
---@field toggle snacks.toggle
---@field util snacks.util
---@field win snacks.win
---@field words snacks.words
---@field zen snacks.zen
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
---@param defaults snacks.win.Config|{}
---@return string
Snacks.config.style(name, defaults)
```

### `Snacks.setup()`

```lua
---@param opts snacks.Config?
Snacks.setup(opts)
```
