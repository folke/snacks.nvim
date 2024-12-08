# 🍿 indent

<!-- docgen -->

## 📦 Setup

```lua
-- lazy.nvim
{
  "folke/snacks.nvim",
  opts = {
    indent = {
      -- your indent configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    }
  }
}
```

## ⚙️ Config

```lua
---@class snacks.indent.Config
---@field enabled? boolean
{
  indent = {
    char = "│",
    blank = " ",
    -- blank = "∙",
    only_scope = false, -- only show indent guides of the scope
    only_current = false, -- only show indent guides in the current window
    hl = "SnacksIndent", ---@type string|string[] hl groups for indent guides
    -- can be a list of hl groups to cycle through
    -- hl = {
    --     "SnacksIndent1",
    --     "SnacksIndent2",
    --     "SnacksIndent3",
    --     "SnacksIndent4",
    --     "SnacksIndent5",
    --     "SnacksIndent6",
    --     "SnacksIndent7",
    --     "SnacksIndent8",
    -- },
  },
  ---@class snacks.indent.Scope.Config: snacks.scope.Config
  scope = {
    -- animate scopes. Enabled by default for Neovim >= 0.10
    -- Works on older versions but has to trigger redraws during animation.
    ---@type snacks.animate.Config|{enabled?: boolean}
    animate = {
      enabled = vim.fn.has("nvim-0.10") == 1,
      easing = "linear",
      duration = {
        step = 20, -- ms per step
        total = 500, -- maximum duration
      },
    },
    char = "│",
    underline = false, -- underline the start of the scope
    only_current = false, -- only show scope in the current window
    hl = "SnacksIndentScope", ---@type string|string[] hl group for scopes
  },
  blank = {
    char = " ",
    -- char = "·",
    hl = "SnacksIndentBlank", ---@type string|string[] hl group for blank spaces
  },
  enabled = function(buf)
    return vim.g.snacks_indent ~= false and vim.b[buf].snacks_indent ~= false and vim.bo[buf].buftype == ""
  end,
  priority = 200,
}
```

## 📚 Types

```lua
---@class snacks.indent.Scope: snacks.scope.Scope
---@field win number
---@field step? number
```

## 📦 Module

### `Snacks.indent.animate()`

Animate scope changes

```lua
Snacks.indent.animate()
```

### `Snacks.indent.debug()`

```lua
Snacks.indent.debug()
```

### `Snacks.indent.disable()`

Disable indent guides

```lua
Snacks.indent.disable()
```

### `Snacks.indent.enable()`

Enable indent guides

```lua
Snacks.indent.enable()
```

### `Snacks.indent.on_scope()`

Called when the scope changes

```lua
---@param win number
---@param _buf number
---@param scope snacks.indent.Scope?
---@param prev snacks.indent.Scope?
Snacks.indent.on_scope(win, _buf, scope, prev)
```

### `Snacks.indent.on_win()`

Called during every redraw cycle, so it should be fast.
Everything that can be cached should be cached.

```lua
---@param win number
---@param buf number
---@param top number -- 1-indexed
---@param bottom number -- 1-indexed
Snacks.indent.on_win(win, buf, top, bottom)
```

### `Snacks.indent.render()`

Render the scope overlappping the given range

```lua
---@param scope snacks.indent.Scope
---@param ctx snacks.indent.ctx
Snacks.indent.render(scope, ctx)
```

### `Snacks.indent.setup()`

```lua
Snacks.indent.setup()
```
