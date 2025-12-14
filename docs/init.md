# 🍿 init

<!-- docgen -->

## ⚙️ Config

```lua
---@class snacks.Config
---@field animate? snacks.animate.Config
---@field bigfile? snacks.bigfile.Config
---@field dashboard? snacks.dashboard.Config
---@field dim? snacks.dim.Config
---@field explorer? snacks.explorer.Config
---@field gh? snacks.gh.Config
---@field gitbrowse? snacks.gitbrowse.Config
---@field image? snacks.image.Config
---@field indent? snacks.indent.Config
---@field input? snacks.input.Config
---@field layout? snacks.layout.Config
---@field lazygit? snacks.lazygit.Config
---@field notifier? snacks.notifier.Config
---@field picker? snacks.picker.Config
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
---@field image? snacks.image.Config|{}
{
  image = {
    -- define these here, so that we don't need to load the image module
    formats = {
      "png",
      "jpg",
      "jpeg",
      "gif",
      "bmp",
      "webp",
      "tiff",
      "heic",
      "avif",
      "mp4",
      "mov",
      "avi",
      "mkv",
      "webm",
      "pdf",
      "icns",
    },
  },
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
---@field animate snacks.animate
---@field bigfile snacks.bigfile
---@field bufdelete snacks.bufdelete
---@field dashboard snacks.dashboard
---@field debug snacks.debug
---@field dim snacks.dim
---@field explorer snacks.explorer
---@field gh snacks.gh
---@field git snacks.git
---@field gitbrowse snacks.gitbrowse
---@field health snacks.health
---@field image snacks.image
---@field indent snacks.indent
---@field input snacks.input
---@field keymap snacks.keymap
---@field layout snacks.layout
---@field lazygit snacks.lazygit
---@field meta snacks.meta
---@field notifier snacks.notifier
---@field notify snacks.notify
---@field picker snacks.picker
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

### `Snacks.init.config.example()`

Get an example config from the docs/examples directory.

```lua
---@param snack string
---@param name string
---@param opts? table
Snacks.init.config.example(snack, name, opts)
```

### `Snacks.init.config.get()`

```lua
---@generic T: table
---@param snack string
---@param defaults T
---@param ... T[]
---@return T
Snacks.init.config.get(snack, defaults, ...)
```

### `Snacks.init.config.merge()`

Merges the values similar to vim.tbl_deep_extend with the **force** behavior,
but the values can be any type

```lua
---@generic T
---@param ... T
---@return T
Snacks.init.config.merge(...)
```

### `Snacks.init.config.style()`

Register a new window style config.

```lua
---@param name string
---@param defaults snacks.win.Config|{}
---@return string
Snacks.init.config.style(name, defaults)
```

### `Snacks.init.setup()`

```lua
---@param opts snacks.Config?
Snacks.init.setup(opts)
```
