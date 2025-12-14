# 🍿 statuscolumn

<!-- docgen -->

## 📦 Setup

```lua
-- lazy.nvim
{
  "folke/snacks.nvim",
  ---@type snacks.Config
  opts = {
    statuscolumn = {
      -- your statuscolumn configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    }
  }
}
```

## ⚙️ Config

```lua
---@class snacks.statuscolumn.Config
---@field left snacks.statuscolumn.Components
---@field right snacks.statuscolumn.Components
---@field enabled? boolean
{
  left = { "mark", "sign" }, -- priority of signs on the left (high to low)
  right = { "fold", "git" }, -- priority of signs on the right (high to low)
  folds = {
    open = false, -- show open fold icons
    git_hl = false, -- use Git Signs hl for fold icons
  },
  git = {
    -- patterns to match Git signs
    patterns = { "GitSign", "MiniDiffSign" },
  },
  refresh = 50, -- refresh at most every 50ms
}
```

## 📚 Types

```lua
---@class snacks.statuscolumn.FoldInfo
---@field start number Line number where deepest fold starts
---@field level number Fold level, when zero other fields are N/A
---@field llevel number Lowest level that starts in v:lnum
---@field lines number Number of lines from v:lnum to end of closed fold
```

```lua
---@alias snacks.statuscolumn.Component "mark"|"sign"|"fold"|"git"
---@alias snacks.statuscolumn.Components snacks.statuscolumn.Component[]|fun(win:number,buf:number,lnum:number):snacks.statuscolumn.Component[]
---@alias snacks.statuscolumn.Wanted table<snacks.statuscolumn.Component, boolean>
```

## 📦 Module

### `Snacks.statuscolumn()`

```lua
---@type fun(): string
Snacks.statuscolumn()
```

### `Snacks.statuscolumn.click_fold()`

```lua
Snacks.statuscolumn.click_fold()
```

### `Snacks.statuscolumn.get()`

```lua
Snacks.statuscolumn.get()
```
