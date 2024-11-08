# 🍿 words

Auto-show LSP references and quickly navigate between them

<!-- docgen -->

## ⚙️ Config

```lua
---@class snacks.words.Config
{
  enabled = true, -- enable/disable the plugin
  debounce = 200, -- time in ms to wait before updating
  notify_jump = true, -- show a notification when jumping
  notify_end = true, -- show a notification when reaching the end
}
```

## 📦 Module

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
