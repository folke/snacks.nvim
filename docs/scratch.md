# 🍿 scratch

Quickly open scratch buffers for testing code, creating notes or
just messing around. Scratch buffers are organized by using context
like your working directory, Git branch and `vim.v.count1`.

It supports templates, custom keymaps, and auto-saves when you hide the buffer.

In lua buffers, pressing `<cr>` will execute the buffer / selection with
`Snacks.debug.run()` that will show print output inline and show errors as diagnostics.

![image](https://github.com/user-attachments/assets/52ac7c1a-908f-4d1d-97a2-ad4642f8dc36)

![image](https://github.com/user-attachments/assets/d3e766e9-e64a-4c22-85b4-3d965f645b59)

## 🚀 Usage

Suggested config:

```lua
{
  "folke/snacks.nvim",
  keys = {
    { "<leader>.",  function() Snacks.scratch() end, desc = "Toggle Scratch Buffer" },
    { "<leader>S",  function() Snacks.scratch.select() end, desc = "Select Scratch Buffer" },
  }
}
```

<!-- docgen -->

## 📦 Setup

```lua
-- lazy.nvim
{
  "folke/snacks.nvim",
  ---@type snacks.Config
  opts = {
    scratch = {
      -- your scratch configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    }
  }
}
```

## ⚙️ Config

```lua
---@class snacks.scratch.Config
---@field win? snacks.win.Config scratch window
---@field template? string template for new buffers
---@field file? string scratch file path. You probably don't need to set this.
---@field ft? string|fun():string the filetype of the scratch buffer
{
  name = "Scratch",
  ft = function()
    if vim.bo.buftype == "" and vim.bo.filetype ~= "" then
      return vim.bo.filetype
    end
    return "markdown"
  end,
  ---@type string|string[]?
  icon = nil, -- `icon|{icon, icon_hl}`. defaults to the filetype icon
  root = vim.fn.stdpath("data") .. "/scratch",
  autowrite = true, -- automatically write when the buffer is hidden
  -- unique key for the scratch file is based on:
  -- * name
  -- * ft
  -- * vim.v.count1 (useful for keymaps)
  -- * cwd (optional)
  -- * branch (optional)
  filekey = {
    cwd = true, -- use current working directory
    branch = true, -- use current branch name
    count = true, -- use vim.v.count1
  },
  win = { style = "scratch" },
  ---@type table<string, snacks.win.Config>
  win_by_ft = {
    lua = {
      keys = {
        ["source"] = {
          "<cr>",
          function(self)
            local name = "scratch." .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(self.buf), ":e")
            Snacks.debug.run({ buf = self.buf, name = name })
          end,
          desc = "Source buffer",
          mode = { "n", "x" },
        },
      },
    },
  },
}
```

## 🎨 Styles

Check the [styles](https://github.com/folke/snacks.nvim/blob/main/docs/styles.md)
docs for more information on how to customize these styles

### `scratch`

```lua
{
  width = 100,
  height = 30,
  bo = { buftype = "", buflisted = false, bufhidden = "hide", swapfile = false },
  minimal = false,
  noautocmd = false,
  -- position = "right",
  zindex = 20,
  wo = { winhighlight = "NormalFloat:Normal" },
  footer_keys = true,
  border = true,
}
```

## 📚 Types

```lua
---@class snacks.scratch.File
---@field file string full path to the scratch buffer
---@field stat uv.fs_stat.result File stat result
---@field name string name of the scratch buffer
---@field ft string file type
---@field icon? string icon for the file type
---@field cwd? string current working directory
---@field branch? string Git branch
---@field count? number vim.v.count1 used to open the buffer
```

## 📦 Module

### `Snacks.scratch()`

```lua
---@type fun(opts?: snacks.scratch.Config): snacks.win
Snacks.scratch()
```

### `Snacks.scratch.list()`

Return a list of scratch buffers sorted by mtime.

```lua
---@return snacks.scratch.File[]
Snacks.scratch.list()
```

### `Snacks.scratch.open()`

Open a scratch buffer with the given options.
If a window is already open with the same buffer,
it will be closed instead.

```lua
---@param opts? snacks.scratch.Config
Snacks.scratch.open(opts)
```

### `Snacks.scratch.select()`

Select a scratch buffer from a list of scratch buffers.

```lua
Snacks.scratch.select()
```
