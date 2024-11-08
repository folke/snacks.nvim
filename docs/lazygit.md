# 🍿 lazygit

Automatically configures lazygit with a theme generated based on your Neovim colorscheme
and integrate edit with the current neovim instance.

![image](https://github.com/user-attachments/assets/5e5ca232-af65-4ebc-b0ca-02bc9c33d23d)

<!-- docgen -->

## ⚙️ Config

```lua
---@class snacks.lazygit.Config: snacks.terminal.Opts
---@field args? string[]
---@field gui? snacks.lazygit.Gui
---@field theme? snacks.lazygit.Theme
{
  -- automatically configure lazygit to use the current colorscheme
  -- and integrate edit with the current neovim instance
  configure = true,
  theme_path = vim.fs.normalize(vim.fn.stdpath("cache") .. "/lazygit-theme.yml"),
  -- Theme for lazygit
  theme = {
    [241]                      = { fg = "Special" },
    activeBorderColor          = { fg = "MatchParen", bold = true },
    cherryPickedCommitBgColor  = { fg = "Identifier" },
    cherryPickedCommitFgColor  = { fg = "Function" },
    defaultFgColor             = { fg = "Normal" },
    inactiveBorderColor        = { fg = "FloatBorder" },
    optionsTextColor           = { fg = "Function" },
    searchingActiveBorderColor = { fg = "MatchParen", bold = true },
    selectedLineBgColor        = { bg = "Visual" }, -- set to `default` to have no background colour
    unstagedChangesColor       = { fg = "DiagnosticError" },
  },
  gui = {
    border = "rounded",
  },
  win = {
    style = "lazygit",
  },
}
```

## 🎨 Styles

### `lazygit`

```lua
{}
```

## 📚 Types

```lua
---@alias snacks.lazygit.Color {fg?:string, bg?:string, bold?:boolean}
```

```lua
---@class snacks.lazygit.Theme: table<number, snacks.lazygit.Color>
---@field activeBorderColor snacks.lazygit.Color
---@field cherryPickedCommitBgColor snacks.lazygit.Color
---@field cherryPickedCommitFgColor snacks.lazygit.Color
---@field defaultFgColor snacks.lazygit.Color
---@field inactiveBorderColor snacks.lazygit.Color
---@field optionsTextColor snacks.lazygit.Color
---@field searchingActiveBorderColor snacks.lazygit.Color
---@field selectedLineBgColor snacks.lazygit.Color
---@field unstagedChangesColor snacks.lazygit.Color
```

## 📦 Module

### `Snacks.lazygit()`

```lua
---@type fun(opts?: snacks.lazygit.Config): snacks.win
Snacks.lazygit()
```

### `Snacks.lazygit.log()`

Opens lazygit with the log view

```lua
---@param opts? snacks.lazygit.Config
Snacks.lazygit.log(opts)
```

### `Snacks.lazygit.log_file()`

Opens lazygit with the log of the current file

```lua
---@param opts? snacks.lazygit.Config
Snacks.lazygit.log_file(opts)
```

### `Snacks.lazygit.open()`

Opens lazygit, properly configured to use the current colorscheme
and integrate with the current neovim instance

```lua
---@param opts? snacks.lazygit.Config
Snacks.lazygit.open(opts)
```
