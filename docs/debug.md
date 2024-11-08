# 🍿 debug

Utility functions you can use in your code.

Personally, I have the code below at the top of my `init.lua`:

```lua
_G.dd = function(...)
  Snacks.debug.inspect(...)
end
_G.bt = function()
  Snacks.debug.backtrace()
end
vim.print = _G.dd
```

What this does:

- Add a global `dd(...)` you can use anywhere to quickly show a
  notification with a pretty printed dump of the object(s)
  with lua treesitter highlighting
- Add a global `bt()` to show a notification with a pretty
  backtrace.
- Override Neovim's `vim.print`, which is also used by `:= {something = 123}`

![image](https://github.com/user-attachments/assets/0517aed7-fbd0-42ee-8058-c213410d80a7)

<!-- docgen -->

## 📦 Module

### `Snacks.debug()`

```lua
---@type fun(...)
Snacks.debug()
```

### `Snacks.debug.backtrace()`

Show a notification with a pretty backtrace

```lua
Snacks.debug.backtrace()
```

### `Snacks.debug.inspect()`

Show a notification with a pretty printed dump of the object(s)
with lua treesitter highlighting and the location of the caller

```lua
Snacks.debug.inspect(...)
```

### `Snacks.debug.log()`

Log a message to the file `./debug.log`.
- a timestamp will be added to every message.
- accepts multiple arguments and pretty prints them.
- if the argument is not a string, it will be printed using `vim.inspect`.
- if the message is smaller than 120 characters, it will be printed on a single line.

```lua
Snacks.debug.log("Hello", { foo = "bar" }, 42)
-- 2024-11-08 08:56:52 Hello { foo = "bar" } 42
```

```lua
Snacks.debug.log(...)
```

### `Snacks.debug.profile()`

Very simple function to profile a lua function.
* **flush**: set to `true` to use `jit.flush` in every iteration.
* **count**: defaults to 100

```lua
---@param fn fun()
---@param opts? {count?: number, flush?: boolean}
Snacks.debug.profile(fn, opts)
```
