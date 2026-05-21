# 🍿 rename

LSP-integrated file renaming with support for plugins like
[neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim) and [mini.files](https://github.com/nvim-mini/mini.files).

## 🚀 Usage

## [mini.files](https://github.com/nvim-mini/mini.files)

```lua
vim.api.nvim_create_autocmd("User", {
  pattern = "MiniFilesActionRename",
  callback = function(event)
    Snacks.rename.on_rename_file(event.data.from, event.data.to)
  end,
})
```

## [oil.nvim](https://github.com/stevearc/oil.nvim)

```lua
vim.api.nvim_create_autocmd("User", {
  pattern = "OilActionsPost",
  callback = function(event)
      if event.data.actions[1].type == "move" then
          Snacks.rename.on_rename_file(event.data.actions[1].src_url, event.data.actions[1].dest_url)
      end
  end,
})
```

## [fyler.nvim](https://github.com/A7Lavinraj/fyler.nvim)

```lua
return {
  "A7Lavinraj/fyler.nvim",
  dependencies = { "echasnovski/mini.icons" },
  opts = {
    hooks = {
      on_rename = function(src_path, destination_path)
        Snacks.rename.on_rename_file(src_path, destination_path)
      end,
    },
  },
}
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
{
  "nvim-tree/nvim-tree.lua",
  opts = {
    on_attach = function(bufnr)
      local api = require("nvim-tree.api")
      api.map.on_attach.default(bufnr)

      vim.keymap.set("n", "r", function()
        local node = api.tree.get_node_under_cursor()
        if not node or node.name == ".." then return end

        local old_path = node.absolute_path
        local old_name = vim.fs.basename(old_path)

        vim.ui.input({ prompt = "Rename to: ", default = old_name }, function(input)
          if not input or input == "" or input == old_name then return end
          Snacks.rename.rename_file({ from = old_path, to = vim.fs.joinpath(vim.fs.dirname(old_path), input) })
        end)
      end, { buffer = bufnr })
    end,
  },
}
```

## netrw (builtin file explorer)

```lua
vim.api.nvim_create_autocmd({ 'FileType' }, {
  pattern = { 'netrw' },
  group = vim.api.nvim_create_augroup('NetrwOnRename', { clear = true }),
  callback = function()
    vim.keymap.set("n", "R", function()
      local original_file_path = vim.b.netrw_curdir .. '/' .. vim.fn["netrw#Call"]("NetrwGetWord")

      vim.ui.input({ prompt = 'Move/rename to:', default = original_file_path }, function(target_file_path)
        if target_file_path and target_file_path ~= "" then
          local file_exists = vim.uv.fs_access(target_file_path, "W")

          if not file_exists then
            vim.uv.fs_rename(original_file_path, target_file_path)

            Snacks.rename.on_rename_file(original_file_path, target_file_path)
          else
            vim.notify("File '" .. target_file_path .. "' already exists! Skipping...", vim.log.levels.ERROR)
          end

          -- Refresh netrw
          vim.cmd(':Ex ' .. vim.b.netrw_curdir)
        end
      end)
    end, { remap = true, buffer = true })
  end
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

Renames the provided file, or the current buffer's file.
Prompt for the new filename if `to` is not provided.
do the rename, and trigger LSP handlers

```lua
---@param opts? {from?: string, to?:string, on_rename?: fun(to:string, from:string, ok:boolean)}
Snacks.rename.rename_file(opts)
```
