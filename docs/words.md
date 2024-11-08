# 🍿 words

Auto-show LSP references and quickly navigate between them

<!-- docgen -->

## ⚙️ Config

```lua
---@class snacks.words.Config
{
  enabled = true, -- enable/disable the plugin
  debounce = 200, -- time in ms to wait before updating
  notify_jump = false, -- show a notification when jumping
  notify_end = true, -- show a notification when reaching the end
  foldopen = true, -- open folds after jumping
  jumplist = true, -- set jump point before jumping
  modes = { "n", "i", "c" }, -- modes to show references
}
```

## 📦 Module

### `Snacks.words.clear()`

```lua
Snacks.words.clear()
```

### `Snacks.words.is_enabled()`

```lua
---@param buf number?
Snacks.words.is_enabled(buf)
```

### `Snacks.words.jump()`

```lua
---@param count number
---@param cycle? boolean
Snacks.words.jump(count, cycle)
```
