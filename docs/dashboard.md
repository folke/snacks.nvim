# 🍿 dashboard

## ✨ Features

- declarative configuration
- flexible layouts
- multiple vertical panes
- built-in sections:
  - **header**: show a header
  - **keys**: show keymaps
  - **projects**: show recent projects
  - **recent_files**: show recent files
  - **session**: session support
  - **startup**: startup time (lazy.nvim)
  - **terminal**: colored terminal output
- super fast `terminal` sections with automatic caching

## 🚀 Usage

The dashboard comes with a set of default sections, that
can be customized with `opts.preset` or
fully replaced with `opts.sections`.

The default preset comes with support for:

- pickers:
  - [fzf-lua](https://github.com/ibhagwan/fzf-lua)
  - [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
  - [mini.pick](https://github.com/nvim-mini/mini.pick)
- session managers: (only works with [lazy.nvim](https://github.com/folke/lazy.nvim))
  - [persistence.nvim](https://github.com/folke/persistence.nvim)
  - [persisted.nvim](https://github.com/olimorris/persisted.nvim)
  - [neovim-session-manager](https://github.com/Shatur/neovim-session-manager)
  - [posession.nvim](https://github.com/jedrzejboczar/possession.nvim)
  - [mini.sessions](https://github.com/nvim-mini/mini.sessions)

### Section actions

A section can have an `action` property that will be executed as:

- a command if it starts with `:`
- a keymap if it's a string not starting with `:`
- a function if it's a function

```lua
-- command
{
  action = ":Telescope find_files",
  key = "f",
},
```

```lua
-- keymap
{
  action = "<leader>ff",
  key = "f",
},
```

```lua
-- function
{
  action = function()
    require("telescope.builtin").find_files()
  end,
  key = "h",
},
```

### Item text

Every item should have a `text` property with an array of `snacks.dashboard.Text` objects.
If the `text` property is not provided, the `snacks.dashboard.Config.formats`
will be used to generate the text.

In the example below, both sections are equivalent.

```lua
{
  text = {
    { "  ", hl = "SnacksDashboardIcon" },
    { "Find File", hl = "SnacksDashboardDesc", width = 50 },
    { "[f]", hl = "SnacksDashboardKey" },
  },
  action = ":Telescope find_files",
  key = "f",
},
```

```lua
{
  action = ":Telescope find_files",
  key = "f",
  desc = "Find File",
  icon = " ",
},
```

<!-- docgen -->

## 📦 Setup

```lua
-- lazy.nvim
{
  "folke/snacks.nvim",
  ---@type snacks.Config
  opts = {
    dashboard = {
      -- your dashboard configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    }
  }
}
```

## ⚙️ Config

```lua
---@class snacks.dashboard.Config
---@field enabled? boolean
---@field sections snacks.dashboard.Section
---@field formats table<string, snacks.dashboard.Text|fun(item:snacks.dashboard.Item, ctx:snacks.dashboard.Format.ctx):snacks.dashboard.Text>
{
  width = 60,
  row = nil, -- dashboard position. nil for center
  col = nil, -- dashboard position. nil for center
  pane_gap = 4, -- empty columns between vertical panes
  autokeys = "1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ", -- autokey sequence
  -- These settings are used by some built-in sections
  preset = {
    -- Defaults to a picker that supports `fzf-lua`, `telescope.nvim` and `mini.pick`
    ---@type fun(cmd:string, opts:table)|nil
    pick = nil,
    -- Used by the `keys` section to show keymaps.
    -- Set your custom keymaps here.
    -- When using a function, the `items` argument are the default keymaps.
    ---@type snacks.dashboard.Item[]
    keys = {
      { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
      { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
      { icon = " ", key = "g", desc = "Find Text", action = ":lua Snacks.dashboard.pick('live_grep')" },
      { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
      { icon = " ", key = "c", desc = "Config", action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
      { icon = " ", key = "s", desc = "Restore Session", section = "session" },
      { icon = "󰒲 ", key = "L", desc = "Lazy", action = ":Lazy", enabled = package.loaded.lazy ~= nil },
      { icon = " ", key = "q", desc = "Quit", action = ":qa" },
    },
    -- Used by the `header` section
    header = [[
███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝]],
  },
  -- item field formatters
  formats = {
    icon = function(item)
      if item.file and item.icon == "file" or item.icon == "directory" then
        return M.icon(item.file, item.icon)
      end
      return { item.icon, width = 2, hl = "icon" }
    end,
    footer = { "%s", align = "center" },
    header = { "%s", align = "center" },
    file = function(item, ctx)
      local fname = vim.fn.fnamemodify(item.file, ":~")
      fname = ctx.width and #fname > ctx.width and vim.fn.pathshorten(fname) or fname
      if #fname > ctx.width then
        local dir = vim.fn.fnamemodify(fname, ":h")
        local file = vim.fn.fnamemodify(fname, ":t")
        if dir and file then
          file = file:sub(-(ctx.width - #dir - 2))
          fname = dir .. "/…" .. file
        end
      end
      local dir, file = fname:match("^(.*)/(.+)$")
      return dir and { { dir .. "/", hl = "dir" }, { file, hl = "file" } } or { { fname, hl = "file" } }
    end,
  },
  sections = {
    { section = "header" },
    { section = "keys", gap = 1, padding = 1 },
    { section = "startup" },
  },
}
```

## 🚀 Examples

### `advanced`

A more advanced example using multiple panes
![image](https://github.com/user-attachments/assets/bbf4d2cd-6fc5-4122-a462-0ca59ba89545)

```lua
{
  sections = {
    { section = "header" },
    {
      pane = 2,
      section = "terminal",
      cmd = "colorscript -e square",
      height = 5,
      padding = 1,
    },
    { section = "keys", gap = 1, padding = 1 },
    { pane = 2, icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 1 },
    { pane = 2, icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1 },
    {
      pane = 2,
      icon = " ",
      title = "Git Status",
      section = "terminal",
      enabled = function()
        return Snacks.git.get_root() ~= nil
      end,
      cmd = "git status --short --branch --renames",
      height = 5,
      padding = 1,
      ttl = 5 * 60,
      indent = 3,
    },
    { section = "startup" },
  },
}
```

### `chafa`

An example using the `chafa` command to display an image
![image](https://github.com/user-attachments/assets/e498ef8f-83ce-4917-a720-8cb31d98ecec)

```lua
{
  sections = {
    {
      section = "terminal",
      cmd = "chafa ~/.config/wall.png --format symbols --symbols vhalf --size 60x17 --stretch; sleep .1",
      height = 17,
      padding = 1,
    },
    {
      pane = 2,
      { section = "keys", gap = 1, padding = 1 },
      { section = "startup" },
    },
  },
}
```

### `compact_files`

A more compact version of the `files` example
![image](https://github.com/user-attachments/assets/772e84fe-b220-4841-bbe9-6e28780dc30a)

```lua
{
  sections = {
    { section = "header" },
    { icon = " ", title = "Keymaps", section = "keys", indent = 2, padding = 1 },
    { icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 1 },
    { icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1 },
    { section = "startup" },
  },
}
```

### `doom`

Similar to the Emacs Doom dashboard
![image](https://github.com/user-attachments/assets/823f702d-e5d0-449a-afd2-684e1fb97622)

```lua
{
  sections = {
    { section = "header" },
    { section = "keys", gap = 1, padding = 1 },
    { section = "startup" },
  },
}
```

### `files`

A simple example with a header, keys, recent files, and projects
![image](https://github.com/user-attachments/assets/e98997b6-07d3-4162-bc06-2768b78fe353)

```lua
{
  sections = {
    { section = "header" },
    { section = "keys", gap = 1 },
    { icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = { 2, 2 } },
    { icon = " ", title = "Projects", section = "projects", indent = 2, padding = 2 },
    { section = "startup" },
  },
}
```

### `github`

Advanced example using the GitHub CLI.
![image](https://github.com/user-attachments/assets/747d7386-ef05-487f-9550-3e5ef94869fc)

```lua
{
  sections = {
    { section = "header" },
    {
      pane = 2,
      section = "terminal",
      cmd = "colorscript -e square",
      height = 5,
      padding = 1,
    },
    { section = "keys", gap = 1, padding = 1 },
    {
      pane = 2,
      icon = " ",
      desc = "Browse Repo",
      padding = 1,
      key = "b",
      action = function()
        Snacks.gitbrowse()
      end,
    },
    function()
      local in_git = Snacks.git.get_root() ~= nil
      local cmds = {
        {
          title = "Notifications",
          cmd = "gh notify -s -a -n5",
          action = function()
            vim.ui.open("https://github.com/notifications")
          end,
          key = "n",
          icon = " ",
          height = 5,
          enabled = true,
        },
        {
          title = "Open Issues",
          cmd = "gh issue list -L 3",
          key = "i",
          action = function()
            vim.fn.jobstart("gh issue list --web", { detach = true })
          end,
          icon = " ",
          height = 7,
        },
        {
          icon = " ",
          title = "Open PRs",
          cmd = "gh pr list -L 3",
          key = "P",
          action = function()
            vim.fn.jobstart("gh pr list --web", { detach = true })
          end,
          height = 7,
        },
        {
          icon = " ",
          title = "Git Status",
          cmd = "git --no-pager diff --stat -B -M -C",
          height = 10,
        },
      }
      return vim.tbl_map(function(cmd)
        return vim.tbl_extend("force", {
          pane = 2,
          section = "terminal",
          enabled = in_git,
          padding = 1,
          ttl = 5 * 60,
          indent = 3,
        }, cmd)
      end, cmds)
    end,
    { section = "startup" },
  },
}
```

### `pokemon`

Pokemons, because why not?
![image](https://github.com/user-attachments/assets/2fb17ecc-8bc0-48d3-a023-aa8dfc70247e)

```lua
{
  sections = {
    { section = "header" },
    { section = "keys", gap = 1, padding = 1 },
    { section = "startup" },
    {
      section = "terminal",
      cmd = "pokemon-colorscripts -r --no-title; sleep .1",
      random = 10,
      pane = 2,
      indent = 4,
      height = 30,
    },
  },
}
```

### `startify`

Similar to the Vim Startify dashboard
![image](https://github.com/user-attachments/assets/561eff8c-ddf0-4de9-8485-e6be18a19c0b)

```lua
{
  formats = {
    key = function(item)
      return { { "[", hl = "special" }, { item.key, hl = "key" }, { "]", hl = "special" } }
    end,
  },
  sections = {
    { section = "terminal", cmd = "fortune -s | cowsay", hl = "header", padding = 1, indent = 8 },
    { title = "MRU", padding = 1 },
    { section = "recent_files", limit = 8, padding = 1 },
    { title = "MRU ", file = vim.fn.fnamemodify(".", ":~"), padding = 1 },
    { section = "recent_files", cwd = true, limit = 8, padding = 1 },
    { title = "Sessions", padding = 1 },
    { section = "projects", padding = 1 },
    { title = "Bookmarks", padding = 1 },
    { section = "keys" },
  },
}
```

## 🎨 Styles

Check the [styles](https://github.com/folke/snacks.nvim/blob/main/docs/styles.md)
docs for more information on how to customize these styles

### `dashboard`

The default style for the dashboard.
When opening the dashboard during startup, only the `bo` and `wo` options are used.
The other options are used with `:lua Snacks.dashboard()`

```lua
{
  zindex = 10,
  height = 0,
  width = 0,
  bo = {
    bufhidden = "wipe",
    buftype = "nofile",
    buflisted = false,
    filetype = "snacks_dashboard",
    swapfile = false,
    undofile = false,
  },
  wo = {
    colorcolumn = "",
    cursorcolumn = false,
    cursorline = false,
    foldmethod = "manual",
    list = false,
    number = false,
    relativenumber = false,
    sidescrolloff = 0,
    signcolumn = "no",
    spell = false,
    statuscolumn = "",
    statusline = "",
    winbar = "",
    winhighlight = "Normal:SnacksDashboardNormal,NormalFloat:SnacksDashboardNormal",
    wrap = false,
  },
}
```

## 📚 Types

```lua
---@class snacks.dashboard.Item
---@field indent? number
---@field align? "left" | "center" | "right"
---@field gap? number the number of empty lines between child items
---@field padding? number | {[1]:number, [2]:number} bottom or {bottom, top} padding
--- The action to run when the section is selected or the key is pressed.
--- * if it's a string starting with `:`, it will be run as a command
--- * if it's a string, it will be executed as a keymap
--- * if it's a function, it will be called
---@field action? snacks.dashboard.Action
---@field enabled? boolean|fun(opts:snacks.dashboard.Opts):boolean if false, the section will be disabled
---@field section? string the name of a section to include. See `Snacks.dashboard.sections`
---@field [string] any section options
---@field key? string shortcut key
---@field hidden? boolean when `true`, the item will not be shown, but the key will still be assigned
---@field autokey? boolean automatically assign a numerical key
---@field label? string
---@field desc? string
---@field file? string
---@field footer? string
---@field header? string
---@field icon? string
---@field title? string
---@field text? string|snacks.dashboard.Text[]
```

```lua
---@alias snacks.dashboard.Format.ctx {width?:number}
---@alias snacks.dashboard.Action string|fun(self:snacks.dashboard.Class)
---@alias snacks.dashboard.Gen fun(self:snacks.dashboard.Class):snacks.dashboard.Section?
---@alias snacks.dashboard.Section snacks.dashboard.Item|snacks.dashboard.Gen|snacks.dashboard.Section[]
```

```lua
---@class snacks.dashboard.Text
---@field [1] string the text
---@field hl? string the highlight group
---@field width? number the width used for alignment
---@field align? "left" | "center" | "right"
```

```lua
---@class snacks.dashboard.Opts: snacks.dashboard.Config
---@field buf? number the buffer to use. If not provided, a new buffer will be created
---@field win? number the window to use. If not provided, a new floating window will be created
```

## 📦 Module

### `Snacks.dashboard()`

```lua
---@type fun(opts?: snacks.dashboard.Opts): snacks.dashboard.Class
Snacks.dashboard()
```

### `Snacks.dashboard.have_plugin()`

Checks if the plugin is installed.
Only works with [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
---@param name string
Snacks.dashboard.have_plugin(name)
```

### `Snacks.dashboard.health()`

```lua
Snacks.dashboard.health()
```

### `Snacks.dashboard.icon()`

Get an icon

```lua
---@param name string
---@param cat? string
---@return snacks.dashboard.Text
Snacks.dashboard.icon(name, cat)
```

### `Snacks.dashboard.oldfiles()`

```lua
---@param opts? {filter?: table<string, boolean>}
---@return fun():string?
Snacks.dashboard.oldfiles(opts)
```

### `Snacks.dashboard.open()`

```lua
---@param opts? snacks.dashboard.Opts
---@return snacks.dashboard.Class
Snacks.dashboard.open(opts)
```

### `Snacks.dashboard.pick()`

Used by the default preset to pick something

```lua
---@param cmd? string
Snacks.dashboard.pick(cmd, opts)
```

### `Snacks.dashboard.sections.header()`

```lua
---@return snacks.dashboard.Gen
Snacks.dashboard.sections.header()
```

### `Snacks.dashboard.sections.keys()`

```lua
---@return snacks.dashboard.Gen
Snacks.dashboard.sections.keys()
```

### `Snacks.dashboard.sections.projects()`

Get the most recent projects based on git roots of recent files.
The default action will change the directory to the project root,
try to restore the session and open the picker if the session is not restored.
You can customize the behavior by providing a custom action.
Use `opts.dirs` to provide a list of directories to use instead of the git roots.

```lua
---@param opts? {limit?:number, dirs?:(string[]|fun():string[]), pick?:boolean, session?:boolean, action?:fun(dir)}
Snacks.dashboard.sections.projects(opts)
```

### `Snacks.dashboard.sections.recent_files()`

Get the most recent files, optionally filtered by the
current working directory or a custom directory.

```lua
---@param opts? {limit?:number, cwd?:string|boolean, filter?:fun(file:string):boolean?}
---@return snacks.dashboard.Gen
Snacks.dashboard.sections.recent_files(opts)
```

### `Snacks.dashboard.sections.session()`

Adds a section to restore the session if any of the supported plugins are installed.

```lua
---@param item? snacks.dashboard.Item
---@return snacks.dashboard.Item?
Snacks.dashboard.sections.session(item)
```

### `Snacks.dashboard.sections.startup()`

Add the startup section

```lua
---@param opts? {icon?:string}
---@return snacks.dashboard.Section?
Snacks.dashboard.sections.startup(opts)
```

### `Snacks.dashboard.sections.terminal()`

```lua
---@param opts {cmd:string|string[], ttl?:number, height?:number, width?:number, random?:number}|snacks.dashboard.Item
---@return snacks.dashboard.Gen
Snacks.dashboard.sections.terminal(opts)
```

### `Snacks.dashboard.setup()`

Check if the dashboard should be opened

```lua
Snacks.dashboard.setup()
```

### `Snacks.dashboard.update()`

Update the dashboard

```lua
Snacks.dashboard.update()
```
