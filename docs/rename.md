# 🍿 rename

LSP-integrated file renaming with support for plugins like
[neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim) and [mini.files](https://github.com/echasnovski/mini.files).

## 🚀 Usage

## [mini.files](https://github.com/echasnovski/mini.files)

```lua
vim.api.nvim_create_autocmd("User", {
  pattern = "MiniFilesActionRename",
  callback = function(event)
    Snacks.rename.on_rename_file(event.data.from, event.data.to)
  end,
})
```

## [neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim)

```lua
{
  "nvim-neo-tree/neo-tree.nvim",
  opts = function(_, opts)
    local function on_move(data)
      Snacks.rename.on_rename_file(data.source, data.destination)
    end
    local events = require("neo-tree.events")
    opts.event_handlers = opts.event_handlers or {}
    vim.list_extend(opts.event_handlers, {
      { event = events.FILE_MOVED, handler = on_move },
      { event = events.FILE_RENAMED, handler = on_move },
    })
  end,
}
```

## [nvim-tree](https://github.com/nvim-tree/nvim-tree.lua)

```lua
local prev = { new_name = "", old_name = "" } -- Prevents duplicate events
vim.api.nvim_create_autocmd("User", {
  pattern = "NvimTreeSetup",
  callback = function()
    local events = require("nvim-tree.api").events
    events.subscribe(events.Event.NodeRenamed, function(data)
      if prev.new_name ~= data.new_name or prev.old_name ~= data.old_name then
        data = data
        Snacks.rename.on_rename_file(data.old_name, data.new_name)
      end
    end)
  end,
})
```

<!-- docgen -->

## 📦 Module

### `Snacks.rename.on_rename_file()`

Lets LSP clients know that a file has been renamed

```lua
---@param from string
---@param to string
---@param rename? fun()
Snacks.rename.on_rename_file(from, to, rename)
```

### `Snacks.rename.rename_file()`

Prompt for the new filename,
do the rename, and trigger LSP handlers

```lua
---@param opts? {file?: string, on_rename?: fun(new:string, old:string)}
Snacks.rename.rename_file(opts)
```
