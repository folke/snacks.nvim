# 🍿 `snacks.nvim`

A collection of small QoL plugins for Neovim.

## ✨ Features

| Snack                                                                               | Description                                                                                                                                                                             | Setup |
| ----------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :---: |
| [bigfile](https://github.com/folke/snacks.nvim/blob/main/docs/bigfile.md)           | Deal with big files                                                                                                                                                                     |  ‼️   |
| [bufdelete](https://github.com/folke/snacks.nvim/blob/main/docs/bufdelete.md)       | Delete buffers without disrupting window layout                                                                                                                                         |       |
| [dashboard](https://github.com/folke/snacks.nvim/blob/main/docs/dashboard.md)       | Beautiful declarative dashboards                                                                                                                                                        |  ‼️   |
| [debug](https://github.com/folke/snacks.nvim/blob/main/docs/debug.md)               | Pretty inspect & backtraces for debugging                                                                                                                                               |       |
| [git](https://github.com/folke/snacks.nvim/blob/main/docs/git.md)                   | Useful functions for Git                                                                                                                                                                |       |
| [gitbrowse](https://github.com/folke/snacks.nvim/blob/main/docs/gitbrowse.md)       | Open the repo of the active file in the browser (e.g., GitHub)                                                                                                                          |       |
| [lazygit](https://github.com/folke/snacks.nvim/blob/main/docs/lazygit.md)           | Open LazyGit in a float, auto-configure colorscheme and integration with Neovim                                                                                                         |       |
| [notify](https://github.com/folke/snacks.nvim/blob/main/docs/notify.md)             | Utility functions to work with Neovim's `vim.notify`                                                                                                                                    |       |
| [notifier](https://github.com/folke/snacks.nvim/blob/main/docs/notifier.md)         | Better and prettier `vim.notify`                                                                                                                                                        |  ‼️   |
| [profiler](https://github.com/folke/snacks.nvim/blob/main/docs/profiler.md)         | Neovim Lua profiler                                                                                                                                                                     |       |
| [quickfile](https://github.com/folke/snacks.nvim/blob/main/docs/quickfile.md)       | When doing `nvim somefile.txt`, it will render the file as quickly as possible, before loading your plugins.                                                                            |  ‼️   |
| [rename](https://github.com/folke/snacks.nvim/blob/main/docs/rename.md)             | LSP-integrated file renaming with support for plugins like [neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim) and [mini.files](https://github.com/echasnovski/mini.files). |       |
| [scratch](https://github.com/folke/snacks.nvim/blob/main/docs/scratch.md)           | Scratch buffers                                                                                                                                                                         |       |
| [statuscolumn](https://github.com/folke/snacks.nvim/blob/main/docs/statuscolumn.md) | Pretty statuscolumn                                                                                                                                                                     |  ‼️   |
| [terminal](https://github.com/folke/snacks.nvim/blob/main/docs/terminal.md)         | Create and toggle floating/split terminals                                                                                                                                              |       |
| [toggle](https://github.com/folke/snacks.nvim/blob/main/docs/toggle.md)             | Toggle keymaps integrated with which-key icons / colors                                                                                                                                 |       |
| [win](https://github.com/folke/snacks.nvim/blob/main/docs/win.md)                   | Easily create and manage floating windows or splits                                                                                                                                     |       |
| [words](https://github.com/folke/snacks.nvim/blob/main/docs/words.md)               | Auto-show LSP references and quickly navigate between them                                                                                                                              |  ‼️   |

## ⚡️ Requirements

- **Neovim** >= 0.9.4
- for proper icons support:
  - [mini.icons](https://github.com/echasnovski/mini.icons) _(optional)_
  - [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons) _(optional)_
  - a [Nerd Font](https://www.nerdfonts.com/) **_(optional)_**

## 📦 Installation

Install the plugin with your package manager:

### [lazy.nvim](https://github.com/folke/lazy.nvim)

> [!important]
> A couple of plugins **require** `snacks.nvim` to be set-up early.
> Setup creates some autocmds and does not load any plugins.
> Check the [code](https://github.com/folke/snacks.nvim/blob/main/lua/snacks/init.lua) to see what it does.

> [!caution]
> You need to explicitely pass options for a plugin or set `enabled = true` to enable it.

> [!tip]
> It' a good idea to run `:checkhealth snacks` to see if everything is set up correctly.

```lua
{
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  opts = {
    -- your configuration comes here
    -- or leave it empty to use the default settings
    -- refer to the configuration section below
    bigfile = { enabled = true },
    notifier = { enabled = true },
    quickfile = { enabled = true },
    statuscolumn = { enabled = true },
    words = { enabled = true },
  },
}
```

For an in-depth setup of `snacks.nvim` with `lazy.nvim`, check the [example](https://github.com/folke/snacks.nvim?tab=readme-ov-file#-usage) below.

## ⚙️ Configuration

Please refer to the readme of each plugin for their specific configuration.

<details><summary>Default Options</summary>

<!-- config:start -->

```lua
---@class snacks.Config
---@field bigfile? snacks.bigfile.Config | { enabled: boolean }
---@field gitbrowse? snacks.gitbrowse.Config
---@field lazygit? snacks.lazygit.Config
---@field notifier? snacks.notifier.Config | { enabled: boolean }
---@field quickfile? { enabled: boolean }
---@field statuscolumn? snacks.statuscolumn.Config  | { enabled: boolean }
---@field styles? table<string, snacks.win.Config>
---@field dashboard? snacks.dashboard.Config  | { enabled: boolean }
---@field terminal? snacks.terminal.Config
---@field toggle? snacks.toggle.Config
---@field win? snacks.win.Config
---@field words? snacks.words.Config
{
  styles = {},
  bigfile = { enabled = false },
  dashboard = { enabled = false },
  notifier = { enabled = false },
  quickfile = { enabled = false },
  statuscolumn = { enabled = false },
  words = { enabled = false },
}
```

<!-- config:end -->

</details>

Some plugins have examples in their documentation. You can include them in your
config like this:

```lua
{
  dashboard = { example = "github" }
}
```

If you want to customize options for a plugin after they have been resolved, you
can use the `config` function:

```lua
{
  gitbrowse = {
    config = function(opts, defaults)
      table.insert(opts.remote_patterns, { "my", "custom pattern" })
    end
  },
}
```

## 🚀 Usage

See the example below for how to configure `snacks.nvim`.

<!-- example:start -->

```lua
{
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    bigfile = { enabled = true },
    dashboard = { enabled = true },
    notifier = {
      enabled = true,
      timeout = 3000,
    },
    quickfile = { enabled = true },
    statuscolumn = { enabled = true },
    words = { enabled = true },
    styles = {
      notification = {
        wo = { wrap = true } -- Wrap notifications
      }
    }
  },
  keys = {
    { "<leader>.",  function() Snacks.scratch() end, desc = "Toggle Scratch Buffer" },
    { "<leader>S",  function() Snacks.scratch.select() end, desc = "Select Scratch Buffer" },
    { "<leader>n",  function() Snacks.notifier.show_history() end, desc = "Notification History" },
    { "<leader>bd", function() Snacks.bufdelete() end, desc = "Delete Buffer" },
    { "<leader>cR", function() Snacks.rename.rename_file() end, desc = "Rename File" },
    { "<leader>gB", function() Snacks.gitbrowse() end, desc = "Git Browse" },
    { "<leader>gb", function() Snacks.git.blame_line() end, desc = "Git Blame Line" },
    { "<leader>gf", function() Snacks.lazygit.log_file() end, desc = "Lazygit Current File History" },
    { "<leader>gg", function() Snacks.lazygit() end, desc = "Lazygit" },
    { "<leader>gl", function() Snacks.lazygit.log() end, desc = "Lazygit Log (cwd)" },
    { "<leader>un", function() Snacks.notifier.hide() end, desc = "Dismiss All Notifications" },
    { "<c-/>",      function() Snacks.terminal() end, desc = "Toggle Terminal" },
    { "<c-_>",      function() Snacks.terminal() end, desc = "which_key_ignore" },
    { "]]",         function() Snacks.words.jump(vim.v.count1) end, desc = "Next Reference", mode = { "n", "t" } },
    { "[[",         function() Snacks.words.jump(-vim.v.count1) end, desc = "Prev Reference", mode = { "n", "t" } },
    {
      "<leader>N",
      desc = "Neovim News",
      function()
        Snacks.win({
          file = vim.api.nvim_get_runtime_file("doc/news.txt", false)[1],
          width = 0.6,
          height = 0.6,
          wo = {
            spell = false,
            wrap = false,
            signcolumn = "yes",
            statuscolumn = " ",
            conceallevel = 3,
          },
        })
      end,
    }
  },
  init = function()
    vim.api.nvim_create_autocmd("User", {
      pattern = "VeryLazy",
      callback = function()
        -- Setup some globals for debugging (lazy-loaded)
        _G.dd = function(...)
          Snacks.debug.inspect(...)
        end
        _G.bt = function()
          Snacks.debug.backtrace()
        end
        vim.print = _G.dd -- Override print to use snacks for `:=` command

        -- Create some toggle mappings
        Snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>us")
        Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
        Snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>uL")
        Snacks.toggle.diagnostics():map("<leader>ud")
        Snacks.toggle.line_number():map("<leader>ul")
        Snacks.toggle.option("conceallevel", { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2 }):map("<leader>uc")
        Snacks.toggle.treesitter():map("<leader>uT")
        Snacks.toggle.option("background", { off = "light", on = "dark", name = "Dark Background" }):map("<leader>ub")
        Snacks.toggle.inlay_hints():map("<leader>uh")
      end,
    })
  end,
}
```

<!-- example:end -->

## 🌈 Highlight Groups

<details>
<summary>Click to see all highlight groups</summary>

<!-- hl_start -->

| Highlight Group               | Default Group           | Description                    |
| ----------------------------- | ----------------------- | ------------------------------ |
| **SnacksNormal**              | _NormalFloat_           | Normal for the float window    |
| **SnacksWinBar**              | _Title_                 | Title of the window            |
| **SnacksBackdrop**            | _none_                  | Backdrop                       |
| **SnacksNormalNC**            | _NormalFloat_           | Normal for non-current windows |
| **SnacksWinBarNC**            | _SnacksWinBar_          | Title for non-current windows  |
| **SnacksScratchKey**          | _DiagnosticVirtualText_ | Keymap help in the footer      |
| **SnacksScratchDesc**         | _DiagnosticInfo_        | Keymap help desc in the footer |
| **SnacksNotifierInfo**        | _none_                  | Notification window for Info   |
| **SnacksNotifierWarn**        | _none_                  | Notification window for Warn   |
| **SnacksNotifierDebug**       | _none_                  | Notification window for Debug  |
| **SnacksNotifierError**       | _none_                  | Notification window for Error  |
| **SnacksNotifierTrace**       | _none_                  | Notification window for Trace  |
| **SnacksNotifierIconInfo**    | _none_                  | Icon for Info notification     |
| **SnacksNotifierIconWarn**    | _none_                  | Icon for Warn notification     |
| **SnacksNotifierIconDebug**   | _none_                  | Icon for Debug notification    |
| **SnacksNotifierIconError**   | _none_                  | Icon for Error notification    |
| **SnacksNotifierIconTrace**   | _none_                  | Icon for Trace notification    |
| **SnacksNotifierTitleInfo**   | _none_                  | Title for Info notification    |
| **SnacksNotifierTitleWarn**   | _none_                  | Title for Warn notification    |
| **SnacksNotifierTitleDebug**  | _none_                  | Title for Debug notification   |
| **SnacksNotifierTitleError**  | _none_                  | Title for Error notification   |
| **SnacksNotifierTitleTrace**  | _none_                  | Title for Trace notification   |
| **SnacksNotifierBorderInfo**  | _none_                  | Border for Info notification   |
| **SnacksNotifierBorderWarn**  | _none_                  | Border for Warn notification   |
| **SnacksNotifierBorderDebug** | _none_                  | Border for Debug notification  |
| **SnacksNotifierBorderError** | _none_                  | Border for Error notification  |
| **SnacksNotifierBorderTrace** | _none_                  | Border for Trace notification  |
| **SnacksNotifierFooterInfo**  | _DiagnosticInfo_        | Footer for Info notification   |
| **SnacksNotifierFooterWarn**  | _DiagnosticWarn_        | Footer for Warn notification   |
| **SnacksNotifierFooterDebug** | _DiagnosticHint_        | Footer for Debug notification  |
| **SnacksNotifierFooterError** | _DiagnosticError_       | Footer for Error notification  |
| **SnacksNotifierFooterTrace** | _DiagnosticHint_        | Footer for Trace notification  |
| **SnacksDashboardNormal**     | _Normal_                | Normal for the dashboard       |
| **SnacksDashboardDesc**       | _Special_               | Description text in dashboard  |
| **SnacksDashboardFile**       | _Special_               | Dashboard file items           |
| **SnacksDashboardDir**        | _NonText_               | Directory items                |
| **SnacksDashboardFooter**     | _Title_                 | Dashboard footer text          |
| **SnacksDashboardHeader**     | _Title_                 | Dashboard header text          |
| **SnacksDashboardIcon**       | _Special_               | Dashboard icons                |
| **SnacksDashboardKey**        | _Number_                | Keybind text                   |
| **SnacksDashboardTerminal**   | _SnacksDashboardNormal_ | Terminal text                  |
| **SnacksDashboardSpecial**    | _Special_               | Special elements               |
| **SnacksDashboardTitle**      | _Title_                 | Title text                     |

<!-- hl_end -->

</details>
