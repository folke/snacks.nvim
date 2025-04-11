# 🍿 bufdelete

Delete buffers without disrupting window layout.

If the buffer you want to close has changes,
a prompt will be shown to save or discard.

<!-- docgen -->

## 📚 Types

```lua
---@class snacks.bufdelete.Opts
---@field buf? number Buffer to delete. Defaults to the current buffer
---@field file? string Delete buffer by file name. If provided, `buf` is ignored
---@field force? boolean Delete the buffer even if it is modified
---@field filter? fun(buf: number): boolean Filter buffers to delete
---@field wipe? boolean Wipe the buffer instead of deleting it (see `:h :bwipeout`)
```

## 📦 Module

### `Snacks.bufdelete()`

```lua
---@type fun(buf?: number|snacks.bufdelete.Opts)
Snacks.bufdelete()
```

### `Snacks.bufdelete.all()`

Delete all buffers

```lua
---@param opts? snacks.bufdelete.Opts
Snacks.bufdelete.all(opts)
```

### `Snacks.bufdelete.delete()`

Delete a buffer:
- either the current buffer if `buf` is not provided
- or the buffer `buf` if it is a number
- or every buffer for which `buf` returns true if it is a function

```lua
---@param opts? number|snacks.bufdelete.Opts
Snacks.bufdelete.delete(opts)
```

### `Snacks.bufdelete.other()`

Delete all buffers except the current one

```lua
---@param opts? snacks.bufdelete.Opts
Snacks.bufdelete.other(opts)
```
