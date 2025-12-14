# 🍿 explorer

A file explorer for snacks. This is actually a [picker](https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#explorer) in disguise.

This module provide a shortcut to open the explorer picker and
a setup function to replace netrw with the explorer.

When the explorer and `replace_netrw` is enabled, the explorer will be opened:

- when you start `nvim` with a directory
- when you open a directory in vim

Configuring the explorer picker is done with the [picker options](https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#explorer).

```lua
-- lazy.nvim
{
  "folke/snacks.nvim",
  ---@type snacks.Config
  opts = {
    explorer = {
      -- your explorer configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    },
    picker = {
      sources = {
        explorer = {
          -- your explorer picker configuration comes here
          -- or leave it empty to use the default settings
        }
      }
    }
  }
}
```

![image](https://github.com/user-attachments/assets/e09d25f8-8559-441c-a0f7-576d2aa57097)

## 🚀 Usage

### File Operations

The explorer provides powerful file operations with an intuitive selection-based workflow.

#### Moving and Copying Files

The most efficient way to move or copy multiple files:

1. **Select files** with `<Tab>` (works on multiple files)
2. **Navigate** to the target directory
3. **Execute** the operation:
   - Press `m` to **move** selected files to the current directory
   - Press `c` to **copy** selected files to the current directory

```
Example workflow:
1. Navigate to source files
2. Press <Tab> on file1.txt
3. Press <Tab> on file2.txt (both now selected)
4. Navigate to target directory
5. Press 'm' → files are moved!
```

**Single file operations:**

- `m` on a single file (no selection) → renames the file
- `c` on a single file (no selection) → prompts for new name to copy to
- `r` → rename current file
- `d` → delete current/selected files

#### Copy/Paste with Registers

Alternative workflow using yank and paste:

1. **Select files** with `<Tab>` or visual mode
2. Press `y` to **yank** file paths to register
3. Navigate to target directory
4. Press `p` to **paste** (copies files from register)

This works across different explorer instances and even after closing/reopening!

#### Other File Operations

- `a` → **Add** new file or directory (directories end with `/`)
- `d` → **Delete** files (uses system trash if available, see `:checkhealth snacks`)
- `o` → **Open** file with system application
- `u` → **Update/refresh** the file tree

### Navigation

- `<CR>` or `l` → Open file or toggle directory
- `h` → Close directory
- `<BS>` → Go up one directory
- `.` → Focus on current directory (set as cwd)
- `H` → Toggle hidden files
- `I` → Toggle ignored files (from gitignore)
- `Z` → Close all directories

### Quick Actions

- `<leader>/` → Grep in current directory
- `<c-t>` → Open terminal in current directory
- `<c-c>` → Change tab directory to current directory
- `P` → Toggle preview

### Git Integration

When `git_status = true` (default), files show git status indicators:

- `]g` / `[g` → Jump to next/previous git change
- Directories show aggregate status of contained files

### Diagnostics

When `diagnostics = true` (default), files show diagnostic indicators:

- `]d` / `[d` → Jump to next/previous diagnostic
- `]e` / `[e` → Jump to next/previous error
- `]w` / `[w` → Jump to next/previous warning

### Visual Mode

You can use visual mode (`v` or `V`) to select multiple files, then:

- `y` → Yank selected file paths
- Any other operation works on visual selection

<!-- docgen -->

## 📦 Setup

```lua
-- lazy.nvim
{
  "folke/snacks.nvim",
  ---@type snacks.Config
  opts = {
    explorer = {
      -- your explorer configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    }
  }
}
```

## ⚙️ Config

These are just the general explorer settings.
To configure the explorer picker, see `snacks.picker.explorer.Config`

```lua
---@class snacks.explorer.Config
{
  replace_netrw = true, -- Replace netrw with the snacks explorer
  trash = true, -- Use the system trash when deleting files
}
```

## 📦 Module

### `Snacks.explorer()`

```lua
---@type fun(opts?: snacks.picker.explorer.Config): snacks.Picker
Snacks.explorer()
```

### `Snacks.explorer.health()`

```lua
Snacks.explorer.health()
```

### `Snacks.explorer.open()`

Shortcut to open the explorer picker

```lua
---@param opts? snacks.picker.explorer.Config|{}
Snacks.explorer.open(opts)
```

### `Snacks.explorer.reveal()`

Reveals the given file/buffer or the current buffer in the explorer

```lua
---@param opts? {file?:string, buf?:number}
Snacks.explorer.reveal(opts)
```
