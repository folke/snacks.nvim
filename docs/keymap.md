# 🍿 keymap

Better `vim.keymap.set` and `vim.keymap.del` with support for filetype-specific and LSP client-aware keymaps.

## ✨ Features

- **Filetype-specific keymaps**: Set keymaps that only apply to specific filetypes
- **LSP-aware keymaps**: Set keymaps based on LSP client capabilities
- **Automatic setup**: Keymaps are automatically applied to existing and new buffers
- **Drop-in replacement**: Same API as `vim.keymap.set/del` with additional options
- **Smart defaults**: Silent by default

## 🚀 Usage

### Filetype-specific Keymaps

Set keymaps that only apply to buffers with specific filetypes:

```lua
-- Single filetype - execute the current lua buffer
Snacks.keymap.set("n", "<localleader>r", function()
  vim.cmd.source()
end, {
  ft = "lua",
  desc = "Run Lua File",
})

-- Multiple filetypes
Snacks.keymap.set("n", "<leader>t", ":TestNearest<cr>", {
  ft = { "python", "ruby", "javascript" },
  desc = "Run Test",
})
```

### LSP-aware Keymaps

Set keymaps based on LSP client capabilities:

```lua
-- Set keymap for buffers with any LSP that supports code actions
Snacks.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, {
  lsp = { method = "textDocument/codeAction" },
  desc = "Code Action",
})

-- Set keymap for buffers with a specific LSP client
Snacks.keymap.set("n", "<leader>co", function()
  vim.lsp.buf.code_action({
    apply = true,
    context = {
      only = { "source.organizeImports" },
      diagnostics = {},
    },
  })
end, {
  lsp = { name = "vtsls" },
  desc = "Organize Imports",
})

-- Set keymap for buffers with LSP that supports definitions
Snacks.keymap.set("n", "gd", vim.lsp.buf.definition, {
  lsp = { method = "textDocument/definition" },
  desc = "Go to Definition",
})
```

### Standard Keymaps

Works exactly like `vim.keymap.set` without special options:

```lua
Snacks.keymap.set("n", "<leader>w", ":w<cr>", { desc = "Save" })
Snacks.keymap.set({ "n", "v" }, "<leader>y", '"+y', { desc = "Copy to clipboard" })
```

### Deleting Keymaps

```lua
-- Delete a standard keymap
Snacks.keymap.del("n", "<leader>w")

-- Delete a filetype-specific keymap
Snacks.keymap.del("n", "<leader><leader>", { ft = "lua" })

-- Delete an LSP-aware keymap
Snacks.keymap.del("n", "<leader>ca", { lsp = { method = "textDocument/codeAction" } })
```

<!-- docgen -->

## 📚 Types

```lua
---@class snacks.keymap.set.Opts: vim.keymap.set.Opts
---@field ft? string|string[] Filetype(s) to set the keymap for.
---@field lsp? vim.lsp.get_clients.Filter Set for buffers with LSP clients matching this filter.
---@field enabled? boolean|fun(buf?:number): boolean condition to enable the keymap.
```

```lua
---@class snacks.keymap.del.Opts: vim.keymap.del.Opts
---@field buffer? boolean|number If true or 0, use the current buffer.
---@field ft? string|string[] Filetype(s) to set the keymap for.
---@field lsp? vim.lsp.get_clients.Filter Set for buffers with LSP clients matching this filter.
```

```lua
---@class snacks.Keymap
---@field mode string|string[] Mode "short-name" (see |nvim_set_keymap()|), or a list thereof.
---@field lhs string           Left-hand side |{lhs}| of the mapping.
---@field rhs string|function  Right-hand side |{rhs}| of the mapping, can be a Lua function.
---@field opts? snacks.keymap.set.Opts
---@field enabled fun(buf?:number): boolean
```

## 📦 Module

### `Snacks.keymap.del()`

```lua
---@param mode string|string[] Mode "short-name" (see |nvim_set_keymap()|), or a list thereof.
---@param lhs string           Left-hand side |{lhs}| of the mapping.
---@param opts? snacks.keymap.del.Opts
Snacks.keymap.del(mode, lhs, opts)
```

### `Snacks.keymap.set()`

```lua
---@param mode string|string[] Mode "short-name" (see |nvim_set_keymap()|), or a list thereof.
---@param lhs string           Left-hand side |{lhs}| of the mapping.
---@param rhs string|function  Right-hand side |{rhs}| of the mapping, can be a Lua function.
---@param opts? snacks.keymap.set.Opts
Snacks.keymap.set(mode, lhs, rhs, opts)
```
