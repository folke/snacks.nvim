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
---@field footer_keys? boolean|string[] Show keys footer. When string[], only show those keys with lhs (default: false)
---@field height? number|fun(self:snacks.win):number Height of the window. Use <1 for relative height. 0 means full height. (default: 0.9)
---@field width? number|fun(self:snacks.win):number Width of the window. Use <1 for relative width. 0 means full width. (default: 0.9)
---@field min_height? number Minimum height of the window
---@field max_height? number Maximum height of the window
---@field min_width? number Minimum width of the window
---@field max_width? number Maximum width of the window
---@field col? number|fun(self:snacks.win):number Column of the window. Use <1 for relative column. (default: center)
---@field row? number|fun(self:snacks.win):number Row of the window. Use <1 for relative row. (default: center)
---@field minimal? boolean Disable a bunch of options to make the window minimal (default: true)
---@field position? "float"|"bottom"|"top"|"left"|"right"|"current"
---@field border? "none"|"top"|"right"|"bottom"|"left"|"top_bottom"|"hpad"|"vpad"|"rounded"|"single"|"double"|"solid"|"shadow"|"bold"|string[]|false|true
---@field buf? number If set, use this buffer instead of creating a new one
---@field file? string If set, use this file instead of creating a new buffer
---@field enter? boolean Enter the window after opening (default: false)
---@field backdrop? number|false|snacks.win.Backdrop Opacity of the backdrop (default: 60)
---@field wo? vim.wo|{} window options
---@field bo? vim.bo|{} buffer options
---@field b? table<string, any> buffer local variables
---@field w? table<string, any> window local variables
---@field ft? string filetype to use for treesitter/syntax highlighting. Won't override existing filetype
---@field scratch_ft? string filetype to use for scratch buffers
---@field keys? table<string, false|string|fun(self: snacks.win)|snacks.win.Keys> Key mappings
---@field on_buf? fun(self: snacks.win) Callback after opening the buffer
---@field on_win? fun(self: snacks.win) Callback after opening the window
---@field on_close? fun(self: snacks.win) Callback after closing the window
---@field fixbuf? boolean don't allow other buffers to be opened in this window
---@field text? string|string[]|fun():(string[]|string) Initial lines to set in the buffer
---@field actions? table<string, snacks.win.Action.spec> Actions that can be used in key mappings
---@field resize? boolean Automatically resize the window when the editor is resized
---@field stack? boolean When enabled, multiple split windows with the same position will be stacked together (useful for terminals)
{
  show = true,
  fixbuf = true,
  relative = "editor",
  position = "float",
  minimal = true,
  wo = {
    winhighlight = "Normal:SnacksNormal,NormalNC:SnacksNormalNC,WinBar:SnacksWinBar,WinBarNC:SnacksWinBarNC,FloatTitle:SnacksTitle,FloatFooter:SnacksFooter,WinSeparator:SnacksWinSeparator",
  },
  bo = {},
  title_pos = "center",
  keys = {
    q = "close",
  },
  footer_pos = "center",
  footer_keys = false,
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

### `help`

```lua
{
  position = "float",
  backdrop = false,
  border = "top",
  row = -1,
  width = 0,
  height = 0.3,
}
```

### `minimal`

```lua
{
  wo = {
    cursorcolumn = false,
    cursorline = false,
    cursorlineopt = "both",
    colorcolumn = "",
    fillchars = "eob: ,lastline:…",
    foldcolumn = "0",
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
---@class snacks.win.Event: vim.api.keyset.create_autocmd
---@field buf? true
---@field win? true
---@field callback? fun(self: snacks.win, ev:vim.api.keyset.create_autocmd.callback_args):boolean?
```

```lua
---@class snacks.win.Backdrop
---@field bg? string
---@field blend? number
---@field transparent? boolean defaults to true
---@field win? snacks.win.Config overrides the backdrop window config
```

```lua
---@class snacks.win.Dim
---@field width number width of the window, without borders
---@field height number height of the window, without borders
---@field row number row of the window (0-indexed)
---@field col number column of the window (0-indexed)
---@field border? boolean whether the window has a border
```

```lua
---@alias snacks.win.Action.fn fun(self: snacks.win):(boolean|string?)
---@alias snacks.win.Action.spec snacks.win.Action|snacks.win.Action.fn
---@class snacks.win.Action
---@field action snacks.win.Action.fn
---@field desc? string
```

## 📦 Module

```lua
---@class snacks.win
---@field id number
---@field buf? number
---@field scratch_buf? number
---@field win? number
---@field opts snacks.win.Config
---@field augroup? number
---@field backdrop? snacks.win
---@field keys snacks.win.Keys[]
---@field events (snacks.win.Event|{event:string|string[]})[]
---@field meta table<string, any>
---@field closed? boolean
Snacks.win = {}
```

### `Snacks.win()`

```lua
---@type fun(opts? :snacks.win.Config|{}): snacks.win
Snacks.win()
```

### `Snacks.win.is_border()`

```lua
Snacks.win.is_border(border)
```

### `Snacks.win.new()`

```lua
---@param opts? snacks.win.Config|{}
---@return snacks.win
Snacks.win.new(opts)
```

### `Snacks.win.zindex()`

Calculate the next available zindex for snacks windows.
New windows open on top of existing ones.

```lua
---@param opts? { zindex?: number, tab?: number|boolean, all?: boolean, max?: number }
---@overload fun(zindex: number): number
Snacks.win.zindex(opts)
```

### `win:action()`

```lua
---@param actions string|string[]
---@return (fun(): boolean|string?) action, string? desc
win:action(actions)
```

### `win:add_padding()`

```lua
win:add_padding()
```

### `win:border()`

```lua
win:border()
```

### `win:border_size()`

Calculate the size of the border

```lua
win:border_size()
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

### `win:destroy()`

```lua
win:destroy()
```

### `win:dim()`

```lua
---@param parent? snacks.win.Dim
win:dim(parent)
```

### `win:execute()`

```lua
---@param actions string|string[]
win:execute(actions)
```

### `win:fixbuf()`

```lua
win:fixbuf()
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

### `win:hscroll()`

```lua
---@param left? boolean
win:hscroll(left)
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

### `win:map()`

```lua
win:map()
```

### `win:on()`

```lua
---@param event string|string[]
---@param cb fun(self: snacks.win, ev:vim.api.keyset.create_autocmd.callback_args):boolean?
---@param opts? snacks.win.Event
win:on(event, cb, opts)
```

### `win:on_current_tab()`

```lua
win:on_current_tab()
```

### `win:on_resize()`

```lua
win:on_resize()
```

### `win:parent_size()`

```lua
---@return { height: number, width: number }
win:parent_size()
```

### `win:redraw()`

```lua
win:redraw()
```

### `win:scratch()`

```lua
win:scratch()
```

### `win:scroll()`

```lua
---@param up? boolean
win:scroll(up)
```

### `win:set_buf()`

```lua
---@param buf number
win:set_buf(buf)
```

### `win:set_title()`

```lua
---@param title string|{[1]:string, [2]:string}[]
---@param pos? "center"|"left"|"right"
win:set_title(title, pos)
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

### `win:toggle_help()`

```lua
---@param opts? {col_width?: number, key_width?: number, win?: snacks.win.Config}
win:toggle_help(opts)
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
