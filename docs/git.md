# 🍿 git

<!-- docgen -->

## 🎨 Styles

Check the [styles](https://github.com/folke/snacks.nvim/blob/main/docs/styles.md)
docs for more information on how to customize these styles

### `blame_line`

```lua
{
  width = 0.6,
  height = 0.6,
  border = true,
  title = " Git Blame ",
  title_pos = "center",
  ft = "git",
}
```

## 📦 Module

### `Snacks.git.blame_line()`

Show git log for the current line.

```lua
---@param opts? snacks.terminal.Opts | {count?: number}
Snacks.git.blame_line(opts)
```

### `Snacks.git.get_root()`

Gets the git root for a buffer or path.
Defaults to the current buffer.

```lua
---@param path? number|string buffer or path
---@return string?
Snacks.git.get_root(path)
```
