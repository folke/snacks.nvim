# 🍿 words

Auto-show LSP references and quickly navigate between them

<!-- docgen -->

## 📦 Setup

```lua
-- lazy.nvim
{
  "folke/snacks.nvim",
  ---@type snacks.Config
  opts = {
    words = {
      -- your words configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    }
  }
}
```

## ⚙️ Config

```lua
---@class snacks.words.Config
---@field enabled? boolean
{
  debounce = 200, -- time in ms to wait before updating
  notify_jump = false, -- show a notification when jumping
  notify_end = true, -- show a notification when reaching the end
  foldopen = true, -- open folds after jumping
  jumplist = true, -- set jump point before jumping
  modes = { "n", "i", "c" }, -- modes to show references
  filter = function(buf) -- what buffers to enable `snacks.words`
    return vim.g.snacks_words ~= false and vim.b[buf].snacks_words ~= false
  end,
}
```

### To customize the highlight colors

```lua
vim.cmd([[highlight LspReferenceText cterm=bold ctermbg=gray guibg=#404010]])
vim.cmd([[highlight LspReferenceRead cterm=bold ctermbg=green guibg=#104010]])
vim.cmd([[highlight LspReferenceWrite cterm=bold ctermbg=red guibg=#401010]])
```

If the LSP notices the identifier is being written to it'll use the `LspReferenceWrite` color, if the identifier is begin read from it'll use the `LspReferenceRead` color, otherwise the fallback color `LspReferenceText` is used.

## 📦 Module

### `Snacks.words.clear()`

```lua
Snacks.words.clear()
```

### `Snacks.words.disable()`

```lua
Snacks.words.disable()
```

### `Snacks.words.enable()`

```lua
Snacks.words.enable()
```

### `Snacks.words.is_enabled()`

```lua
---@param opts? number|{buf?:number, modes:boolean} if modes is true, also check if the current mode is enabled
Snacks.words.is_enabled(opts)
```

### `Snacks.words.jump()`

```lua
---@param count? number
---@param cycle? boolean
Snacks.words.jump(count, cycle)
```
