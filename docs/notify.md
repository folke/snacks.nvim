# 🍿 notify

<!-- docgen -->

## 📚 Types

```lua
---@alias snacks.notify.Opts snacks.notifier.Notif.opts|{once?: boolean}
```

## 📦 Module

### `Snacks.notify()`

```lua
---@type fun(msg: string|string[], opts?: snacks.notify.Opts)
Snacks.notify()
```

### `Snacks.notify.error()`

```lua
---@param msg string|string[]
---@param opts? snacks.notify.Opts
Snacks.notify.error(msg, opts)
```

### `Snacks.notify.info()`

```lua
---@param msg string|string[]
---@param opts? snacks.notify.Opts
Snacks.notify.info(msg, opts)
```

### `Snacks.notify.notify()`

```lua
---@param msg string|string[]
---@param opts? snacks.notify.Opts
Snacks.notify.notify(msg, opts)
```

### `Snacks.notify.warn()`

```lua
---@param msg string|string[]
---@param opts? snacks.notify.Opts
Snacks.notify.warn(msg, opts)
```
