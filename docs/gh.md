# 🍿 gh

A modern GitHub CLI integration for Neovim that brings GitHub issues and pull requests directly into your editor.

<img width="1827" height="1053" alt="Image" src="https://github.com/user-attachments/assets/24b90163-7403-4f42-80b4-9a44758c81b5" />

## ✨ Features

- 📋 Browse and search **GitHub issues** and **pull requests** with fuzzy finding
- 🔍 View full issue/PR details including **comments**, **reactions**, and **status checks**
- 📝 Perform GitHub actions directly from Neovim:
  - Comment on issues and PRs
  - Close, reopen, edit, and merge PRs
  - Add reactions and labels
  - Review PRs (approve, request changes, comment)
  - Checkout PR branches locally
  - View PR diffs with syntax highlighting
- ⌨️ Customizable **keymaps** for common GitHub operations
- 🎨 Beautiful **syntax highlighting** using Treesitter
- 🔗 Open issues/PRs in your web browser
- 📎 Yank URLs to clipboard
- 🌲 Built on top of the powerful [Snacks picker](https://github.com/folke/snacks.nvim/blob/main/docs/picker.md)

## ⚡️ Requirements

- [GitHub CLI (`gh`)](https://cli.github.com/) - must be installed and authenticated
- Snacks [picker](https://github.com/folke/snacks.nvim/blob/main/docs/picker.md) enabled

## 🚀 Recommended Setup

```lua
{
  "folke/snacks.nvim",
  opts = {
    gh = {
      -- your gh configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    },
    picker = {
      sources = {
        gh_issue = {
          -- your gh_issue picker configuration comes here
          -- or leave it empty to use the default settings
        },
        gh_pr = {
          -- your gh_pr picker configuration comes here
          -- or leave it empty to use the default settings
        }
      }
    },
  },
  keys = {
    { "<leader>gi", function() Snacks.picker.gh_issue() end, desc = "GitHub Issues (open)" },
    { "<leader>gI", function() Snacks.picker.gh_issue({ state = "all" }) end, desc = "GitHub Issues (all)" },
    { "<leader>gp", function() Snacks.picker.gh_pr() end, desc = "GitHub Pull Requests (open)" },
    { "<leader>gP", function() Snacks.picker.gh_pr({ state = "all" }) end, desc = "GitHub Pull Requests (all)" },
  },
}
```

## 📚 Usage

```lua
-- Browse open issues
Snacks.picker.gh_issue()

-- Browse all issues (including closed)
Snacks.picker.gh_issue({ state = "all" })

-- Browse open pull requests
Snacks.picker.gh_pr()

-- Browse all pull requests
Snacks.picker.gh_pr({ state = "all" })

-- View PR diff
Snacks.picker.gh_diff({ pr = 123 })

-- Open issue/PR in buffer
Snacks.gh.open({ type = "issue", number = 123, repo = "owner/repo" })
```

### Available Actions

When viewing an issue or PR in the picker, press `<cr>` to show available actions:

<img width="1827" height="1053" alt="Image" src="https://github.com/user-attachments/assets/ec6cdb00-2738-4442-b4e5-3f733e551265" />

`Snacks.gh` makes extensive use of `Snacks.scratch` for editing comments and descriptions.

<img width="1250" height="831" alt="Image" src="https://github.com/user-attachments/assets/37f20d3f-a944-49fa-9572-b78cec386158" />

**Common Actions:**

- **Open in buffer** - View full details with comments
- **Open in browser** - Open in GitHub web UI
- **Add comment** - Add a new comment
- **Add reaction** - React with emoji
- **Add/Remove labels** - Manage labels
- **Close/Reopen** - Change issue/PR state
- **Edit** - Edit title and body
- **Yank URL** - Copy URL to clipboard

**Pull Request/Issue Specific:**

- **View diff** - Show changed files with syntax highlighting
- **Checkout** - Checkout PR branch locally
- **Merge** - Merge, squash, or rebase and merge
- **Review** - Approve, request changes, or comment
- **Mark as draft/ready** - Change draft status
- and more...

<img width="1827" height="1053" alt="Image" src="https://github.com/user-attachments/assets/04aff0f5-3676-4555-a9e7-9b6fb21a9321" />

### GitHub Buffers

When you open an issue or PR in a buffer, you get a beautiful rendered view with:

- **Metadata** - Status, author, dates, labels, reactions, and assignees
- **Description** - Full issue/PR body with markdown rendering
- **Comments** - All comments with author info and timestamps
- **Status Checks** - PR status checks and CI results (for PRs)
- **Syntax Highlighting** - Full Treesitter support for markdown
- **Folding** - Foldable sections for comments and metadata

**Default Keymaps in GitHub Buffers:**

| Key    | Action        | Description                  |
| ------ | ------------- | ---------------------------- |
| `<cr>` | Select Action | Show available actions menu  |
| `i`    | Edit          | Edit issue/PR title and body |
| `a`    | Add Comment   | Add a new comment            |
| `c`    | Close         | Close the issue/PR           |
| `o`    | Reopen        | Reopen a closed issue/PR     |

See the [config section](#%EF%B8%8F-config) to customize these keymaps.

<!-- docgen -->

## 📦 Setup

```lua
-- lazy.nvim
{
  "folke/snacks.nvim",
  ---@type snacks.Config
  opts = {
    gh = {
      -- your gh configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    }
  }
}
```

## ⚙️ Config

```lua
---@class snacks.gh.Config
{
  --- Keymaps for GitHub buffers
  ---@type table<string, snacks.gh.Keymap|false>?
  keys = {
    select  = { "<cr>", "gh_actions", desc = "Select Action" },
    edit    = { "i"   , "gh_edit"   , desc = "Edit" },
    comment = { "a"   , "gh_comment", desc = "Add Comment" },
    close   = { "c"   , "gh_close"  , desc = "Close" },
    reopen  = { "o"   , "gh_reopen" , desc = "Reopen" },
  },
  ---@type vim.wo|{}
  wo = {
    breakindent = true,
    wrap = true,
    showbreak = "",
    linebreak = true,
    number = false,
    relativenumber = false,
    foldexpr = "v:lua.vim.treesitter.foldexpr()",
    foldmethod = "expr",
    concealcursor = "n",
    conceallevel = 2,
    list = false,
    winhighlight = Snacks.util.winhl({
      Normal = "SnacksGhNormal",
      NormalFloat = "SnacksGhNormalFloat",
      FloatBorder = "SnacksGhBorder",
      FloatTitle = "SnacksGhTitle",
      FloatFooter = "SnacksGhFooter",
    }),
  },
  ---@type vim.bo|{}
  bo = {},
  diff = {
    min = 4, -- minimum number of lines changed to show diff
    wrap = 80, -- wrap diff lines at this length
  },
  scratch = {
    height = 15, -- height of scratch window
  },
  icons = {
    logo = " ",
    user= " ",
    checkmark = " ",
    crossmark = " ",
    block = "■",
    file = " ",
    checks = {
      pending = " ",
      success = " ",
      failure = "",
      skipped = " ",
    },
    issue = {
      open      = " ",
      completed = " ",
      other     = " "
    },
    pr = {
      open   = " ",
      closed = " ",
      merged = " ",
      draft  = " ",
      other  = " ",
    },
    review = {
      approved           = " ",
      changes_requested  = " ",
      commented          = " ",
      dismissed          = " ",
      pending            = " ",
    },
    merge_status = {
      clean    = " ",
      dirty    = " ",
      blocked  = " ",
      unstable = " "
    },
    reactions = {
      thumbs_up   = "👍",
      thumbs_down = "👎",
      eyes        = "👀",
      confused    = "😕",
      heart       = "❤️",
      hooray      = "🎉",
      laugh       = "😄",
      rocket      = "🚀",
    },
  },
}
```

## 📚 Types

```lua
---@alias snacks.gh.Keymap.fn fun(item:snacks.picker.gh.Item, buf:snacks.gh.Buf)
---@class snacks.gh.Keymap: vim.keymap.set.Opts
---@field [1] string lhs
---@field [2] string|snacks.gh.Keymap.fn rhs
---@field mode? string|string[] defaults to `n`
```

## 📦 Module

```lua
---@class snacks.gh
---@field api snacks.gh.api
---@field item snacks.picker.gh.Item
Snacks.gh = {}
```

### `Snacks.gh.issue()`

```lua
---@param opts? snacks.picker.gh.issue.Config
Snacks.gh.issue(opts)
```

### `Snacks.gh.pr()`

```lua
---@param opts? snacks.picker.gh.pr.Config
Snacks.gh.pr(opts)
```
