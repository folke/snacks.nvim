# 🍿 animate

<!-- docgen -->

## 📦 Setup

```lua
-- lazy.nvim
{
  "folke/snacks.nvim",
  opts = {
    animate = {
      -- your animate configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    }
  }
}
```

## ⚙️ Config

```lua
---@class snacks.animate.Config
---@field easing? snacks.animate.easing|snacks.animate.easing.Fn
{
  ---@type snacks.animate.Duration|number
  duration = 20, -- ms per step
  easing = "linear",
  fps = 30, -- frames per second. Global setting for all animations
}
```

## 📚 Types

All easing functions take these parameters:

t = time     should go from 0 to duration
b = begin    value of the property being ease.
c = change   ending value of the property - beginning value of the property
d = duration

Some functions allow additional modifiers, like the elastic functions
which also can receive an amplitud and a period parameters (defaults
are included)

```lua
---@alias snacks.animate.easing.Fn fun(t: number, b: number, c: number, d: number): number
```

```lua
---@class snacks.animate.Duration
---@field step? number ms per step. If total is also set, this is the maximum duration
---@field total? number maximum duration in ms
```

```lua
---@class snacks.animate.Opts: snacks.animate.Config
---@field int? boolean interpolate the value to an integer
---@field id? number|string unique identifier for the animation
```

```lua
---@class snacks.animate.Animation
---@field from number
---@field to number
---@field duration number
---@field easing snacks.animate.easing.Fn
---@field value number
---@field start number
---@field int boolean
---@field cb fun(value: number, prev?: number)
```

## 📦 Module

### `Snacks.animate()`

```lua
---@type fun(from: number, to: number, cb: fun(value: number, prev?: number), opts?: snacks.animate.Opts)
Snacks.animate()
```

### `Snacks.animate.animate()`

```lua
---@param from number
---@param to number
---@param cb fun(value: number, prev?: number)
---@param opts? snacks.animate.Opts
Snacks.animate.animate(from, to, cb, opts)
```

### `Snacks.animate.start()`

```lua
Snacks.animate.start()
```

### `Snacks.animate.step()`

```lua
Snacks.animate.step()
```
