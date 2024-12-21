# 🍿 win

Easily create and manage floating windows or splits

## 🚀 Usage

```lua
Snacks.win({
  file = vim.api.nvim_get_runtime_file("doc/news.txt", false)[1],
  width = 0.6,
  height = 0.6,
  wo = {
    spell = false,
    wrap = false,
    signcolumn = "yes",
    statuscolumn = " ",
    conceallevel = 3,
  },
})
```
![image](https://github.com/user-attachments/assets/250acfbd-a624-4f42-a36b-9aab316ebf64)

<!-- docgen -->

## 📦 Setup

```lua
-- lazy.nvim
{
  "folke/snacks.nvim",
  ---@type snacks.Config
  opts = {
    win = {
      -- your win configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    }
  }
}
```

## ⚙️ Config

```lua
---@class snacks.win.Config: vim.api.keyset.win_config
---@field style? string merges with config from `Snacks.config.styles[style]`
---@field show? boolean Show the window immediately (default: true)
---@field height? number|fun(self:snacks.win):number Height of the window. Use <1 for relative height. 0 means full height. (default: 0.9)
---@field width? number|fun(self:snacks.win):number Width of the window. Use <1 for relative width. 0 means full width. (default: 0.9)
---@field minimal? boolean Disable a bunch of options to make the window minimal (default: true)
---@field position? "float"|"bottom"|"top"|"left"|"right"
---@field buf? number If set, use this buffer instead of creating a new one
---@field file? string If set, use this file instead of creating a new buffer
---@field enter? boolean Enter the window after opening (default: false)
---@field backdrop? number|false|snacks.win.Backdrop Opacity of the backdrop (default: 60)
---@field wo? vim.wo|{} window options
---@field bo? vim.bo|{} buffer options
---@field b? table<string, any> buffer local variables
---@field w? table<string, any> window local variables
---@field ft? string filetype to use for treesitter/syntax highlighting. Won't override existing filetype
---@field keys? table<string, false|string|fun(self: snacks.win)|snacks.win.Keys> Key mappings
---@field on_buf? fun(self: snacks.win) Callback after opening the buffer
---@field on_win? fun(self: snacks.win) Callback after opening the window
---@field fixbuf? boolean don't allow other buffers to be opened in this window
---@field text? string|string[]|fun():(string[]|string) Initial lines to set in the buffer
---@field actions? table<string, fun(self: snacks.win):(boolean|string?)> Actions that can be used in key mappings
{
  show = true,
  fixbuf = true,
  relative = "editor",
  position = "float",
  minimal = true,
  wo = {
    winhighlight = "Normal:SnacksNormal,NormalNC:SnacksNormalNC,WinBar:SnacksWinBar,WinBarNC:SnacksWinBarNC",
  },
  bo = {},
  keys = {
    q = "close",
  },
}
```

## 🎨 Styles

Check the [styles](https://github.com/folke/snacks.nvim/blob/main/docs/styles.md)
docs for more information on how to customize these styles

### `float`

```lua
{
  position = "float",
  backdrop = 60,
  height = 0.9,
  width = 0.9,
  zindex = 50,
}
```

### `minimal`

```lua
{
  wo = {
    cursorcolumn = false,
    cursorline = false,
    cursorlineopt = "both",
    fillchars = "eob: ,lastline:…",
    list = false,
    listchars = "extends:…,tab:  ",
    number = false,
    relativenumber = false,
    signcolumn = "no",
    spell = false,
    winbar = "",
    statuscolumn = "",
    wrap = false,
    sidescrolloff = 0,
  },
}
```

### `split`

```lua
{
  position = "bottom",
  height = 0.4,
  width = 0.4,
}
```

## 📚 Types

```lua
---@class snacks.win.Keys: vim.api.keyset.keymap
---@field [1]? string
---@field [2]? string|string[]|fun(self: snacks.win): string?
---@field mode? string|string[]
```

```lua
---@class snacks.win.Backdrop
---@field bg? string
---@field blend? number
---@field transparent? boolean defaults to true
---@field win? snacks.win.Config overrides the backdrop window config
```

## 📦 Module

```lua
---@class snacks.win
---@field id number
---@field buf? number
---@field win? number
---@field opts snacks.win.Config
---@field augroup? number
---@field backdrop? snacks.win
---@field keys snacks.win.Keys[]
Snacks.win = {}
```

### `Snacks.win()`

```lua
---@type fun(opts? :snacks.win.Config|{}): snacks.win
Snacks.win()
```

### `Snacks.win.new()`

```lua
---@param opts? snacks.win.Config|{}
---@return snacks.win
Snacks.win.new(opts)
```

### `win:action()`

```lua
---@param actions string|string[]
---@return fun(): boolean|string?
win:action(actions)
```

### `win:add_padding()`

```lua
win:add_padding()
```

### `win:border_text_width()`

```lua
win:border_text_width()
```

### `win:buf_valid()`

```lua
win:buf_valid()
```

### `win:close()`

```lua
---@param opts? { buf: boolean }
win:close(opts)
```

### `win:focus()`

```lua
win:focus()
```

### `win:has_border()`

```lua
win:has_border()
```

### `win:hide()`

```lua
win:hide()
```

### `win:is_floating()`

```lua
win:is_floating()
```

### `win:line()`

```lua
win:line(line)
```

### `win:lines()`

```lua
---@param from? number 1-indexed, inclusive
---@param to? number 1-indexed, inclusive
win:lines(from, to)
```

### `win:parent_size()`

```lua
win:parent_size()
```

### `win:show()`

```lua
win:show()
```

### `win:size()`

```lua
---@return { height: number, width: number }
win:size()
```

### `win:text()`

```lua
---@param from? number 1-indexed, inclusive
---@param to? number 1-indexed, inclusive
win:text(from, to)
```

### `win:toggle()`

```lua
win:toggle()
```

### `win:update()`

```lua
win:update()
```

### `win:valid()`

```lua
win:valid()
```

### `win:win_valid()`

```lua
win:win_valid()
```
