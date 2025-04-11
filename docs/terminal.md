# 🍿 terminal

Create and toggle terminal windows.

Based on the provided options, some defaults will be set:

- if no `cmd` is provided, the window will be opened in a bottom split
- if `cmd` is provided, the window will be opened in a floating window
- for splits, a `winbar` will be added with the terminal title

![image](https://github.com/user-attachments/assets/afcc9989-57d7-4518-a390-cc7d6f0cec13)

## 🚀 Usage

### Edgy Integration

```lua
{
  "folke/edgy.nvim",
  ---@module 'edgy'
  ---@param opts Edgy.Config
  opts = function(_, opts)
    for _, pos in ipairs({ "top", "bottom", "left", "right" }) do
      opts[pos] = opts[pos] or {}
      table.insert(opts[pos], {
        ft = "snacks_terminal",
        size = { height = 0.4 },
        title = "%{b:snacks_terminal.id}: %{b:term_title}",
        filter = function(_buf, win)
          return vim.w[win].snacks_win
            and vim.w[win].snacks_win.position == pos
            and vim.w[win].snacks_win.relative == "editor"
            and not vim.w[win].trouble_preview
        end,
      })
    end
  end,
}
```

<!-- docgen -->

## 📦 Setup

```lua
-- lazy.nvim
{
  "folke/snacks.nvim",
  ---@type snacks.Config
  opts = {
    terminal = {
      -- your terminal configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    }
  }
}
```

## ⚙️ Config

```lua
---@class snacks.terminal.Config
---@field win? snacks.win.Config|{}
---@field shell? string|string[] The shell to use. Defaults to `vim.o.shell`
---@field override? fun(cmd?: string|string[], opts?: snacks.terminal.Opts) Use this to use a different terminal implementation
{
  win = { style = "terminal" },
}
```

## 🎨 Styles

Check the [styles](https://github.com/folke/snacks.nvim/blob/main/docs/styles.md)
docs for more information on how to customize these styles

### `terminal`

```lua
{
  bo = {
    filetype = "snacks_terminal",
  },
  wo = {},
  keys = {
    q = "hide",
    gf = function(self)
      local f = vim.fn.findfile(vim.fn.expand("<cfile>"), "**")
      if f == "" then
        Snacks.notify.warn("No file under cursor")
      else
        self:hide()
        vim.schedule(function()
          vim.cmd("e " .. f)
        end)
      end
    end,
    term_normal = {
      "<esc>",
      function(self)
        self.esc_timer = self.esc_timer or (vim.uv or vim.loop).new_timer()
        if self.esc_timer:is_active() then
          self.esc_timer:stop()
          vim.cmd("stopinsert")
        else
          self.esc_timer:start(200, 0, function() end)
          return "<esc>"
        end
      end,
      mode = "t",
      expr = true,
      desc = "Double escape to normal mode",
    },
  },
}
```

## 📚 Types

```lua
---@class snacks.terminal.Opts: snacks.terminal.Config
---@field cwd? string
---@field env? table<string, string>
---@field start_insert? boolean start insert mode when starting the terminal
---@field auto_insert? boolean start insert mode when entering the terminal buffer
---@field auto_close? boolean close the terminal buffer when the process exits
---@field interactive? boolean shortcut for `start_insert`, `auto_close` and `auto_insert` (default: true)
```

## 📦 Module

```lua
---@class snacks.terminal: snacks.win
---@field cmd? string | string[]
---@field opts snacks.terminal.Opts
Snacks.terminal = {}
```

### `Snacks.terminal()`

```lua
---@type fun(cmd?: string|string[], opts?: snacks.terminal.Opts): snacks.terminal
Snacks.terminal()
```

### `Snacks.terminal.colorize()`

Colorize the current buffer.
Replaces ansii color codes with the actual colors.

Example:

```sh
ls -la --color=always | nvim - -c "lua Snacks.terminal.colorize()"
```

```lua
Snacks.terminal.colorize()
```

### `Snacks.terminal.get()`

Get or create a terminal window.
The terminal id is based on the `cmd`, `cwd`, `env` and `vim.v.count1` options.
`opts.create` defaults to `true`.

```lua
---@param cmd? string | string[]
---@param opts? snacks.terminal.Opts| {create?: boolean}
---@return snacks.win? terminal, boolean? created
Snacks.terminal.get(cmd, opts)
```

### `Snacks.terminal.list()`

```lua
---@return snacks.win[]
Snacks.terminal.list()
```

### `Snacks.terminal.open()`

Open a new terminal window.

```lua
---@param cmd? string | string[]
---@param opts? snacks.terminal.Opts
Snacks.terminal.open(cmd, opts)
```

### `Snacks.terminal.toggle()`

Toggle a terminal window.
The terminal id is based on the `cmd`, `cwd`, `env` and `vim.v.count1` options.

```lua
---@param cmd? string | string[]
---@param opts? snacks.terminal.Opts
Snacks.terminal.toggle(cmd, opts)
```
