# 🍿 notifier

![image](https://github.com/user-attachments/assets/b89eb279-08fb-40b2-9330-9a77014b9389)

## Notification History

![image](https://github.com/user-attachments/assets/0dc449f4-b275-49e4-a25f-f58efcba3079)

## 💡 Examples

<details><summary>Replace a notification</summary>

```lua
-- to replace an existing notification just use the same id.
-- you can also use the return value of the notify function as id.
for i = 1, 10 do
  vim.defer_fn(function()
    vim.notify("Hello " .. i, "info", { id = "test" })
  end, i * 500)
end
```

</details>

<details><summary>Simple LSP Progress</summary>

```lua
vim.api.nvim_create_autocmd("LspProgress", {
  ---@param ev {data: {client_id: integer, params: lsp.ProgressParams}}
  callback = function(ev)
    local spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
    vim.notify(vim.lsp.status(), "info", {
      id = "lsp_progress",
      title = "LSP Progress",
      opts = function(notif)
        notif.icon = ev.data.params.value.kind == "end" and " "
          or spinner[math.floor(vim.uv.hrtime() / (1e6 * 80)) % #spinner + 1]
      end,
    })
  end,
})
```

</details>

<details><summary>Advanced LSP Progress</summary>

![image](https://github.com/user-attachments/assets/a81b411c-150a-43ec-8def-87270c6f8dde)

```lua
---@type table<number, {token:lsp.ProgressToken, msg:string, done:boolean}[]>
local progress = vim.defaulttable()
vim.api.nvim_create_autocmd("LspProgress", {
  ---@param ev {data: {client_id: integer, params: lsp.ProgressParams}}
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    local value = ev.data.params.value --[[@as {percentage?: number, title?: string, message?: string, kind: "begin" | "report" | "end"}]]
    if not client or type(value) ~= "table" then
      return
    end
    local p = progress[client.id]

    for i = 1, #p + 1 do
      if i == #p + 1 or p[i].token == ev.data.params.token then
        p[i] = {
          token = ev.data.params.token,
          msg = ("[%3d%%] %s%s"):format(
            value.kind == "end" and 100 or value.percentage or 100,
            value.title or "",
            value.message and (" **%s**"):format(value.message) or ""
          ),
          done = value.kind == "end",
        }
        break
      end
    end

    local msg = {} ---@type string[]
    progress[client.id] = vim.tbl_filter(function(v)
      return table.insert(msg, v.msg) or not v.done
    end, p)

    local spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
    vim.notify(table.concat(msg, "\n"), "info", {
      id = "lsp_progress",
      title = client.name,
      opts = function(notif)
        notif.icon = #progress[client.id] == 0 and " "
          or spinner[math.floor(vim.uv.hrtime() / (1e6 * 80)) % #spinner + 1]
      end,
    })
  end,
})
```

</details>

<!-- docgen -->

## 📦 Setup

```lua
-- lazy.nvim
{
  "folke/snacks.nvim",
  ---@type snacks.Config
  opts = {
    notifier = {
      -- your notifier configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    }
  }
}
```

## ⚙️ Config

```lua
---@class snacks.notifier.Config
---@field enabled? boolean
---@field keep? fun(notif: snacks.notifier.Notif): boolean # global keep function
---@field filter? fun(notif: snacks.notifier.Notif): boolean # filter our unwanted notifications (return false to hide)
{
  timeout = 3000, -- default timeout in ms
  width = { min = 40, max = 0.4 },
  height = { min = 1, max = 0.6 },
  -- editor margin to keep free. tabline and statusline are taken into account automatically
  margin = { top = 0, right = 1, bottom = 0 },
  padding = true, -- add 1 cell of left/right padding to the notification window
  gap = 0, -- gap between notifications
  sort = { "level", "added" }, -- sort by level and time
  -- minimum log level to display. TRACE is the lowest
  -- all notifications are stored in history
  level = vim.log.levels.TRACE,
  icons = {
    error = " ",
    warn = " ",
    info = " ",
    debug = " ",
    trace = " ",
  },
  keep = function(notif)
    return vim.fn.getcmdpos() > 0
  end,
  ---@type snacks.notifier.style
  style = "compact",
  top_down = true, -- place notifications from top to bottom
  date_format = "%R", -- time format for notifications
  -- format for footer when more lines are available
  -- `%d` is replaced with the number of lines.
  -- only works for styles with a border
  ---@type string|boolean
  more_format = " ↓ %d lines ",
  refresh = 50, -- refresh at most every 50ms
}
```

## 🎨 Styles

Check the [styles](https://github.com/folke/snacks.nvim/blob/main/docs/styles.md)
docs for more information on how to customize these styles

### `notification`

```lua
{
  border = true,
  zindex = 100,
  ft = "markdown",
  wo = {
    winblend = 5,
    wrap = false,
    conceallevel = 2,
    colorcolumn = "",
  },
  bo = { filetype = "snacks_notif" },
}
```

### `notification_history`

```lua
{
  border = true,
  zindex = 100,
  width = 0.6,
  height = 0.6,
  minimal = false,
  title = " Notification History ",
  title_pos = "center",
  ft = "markdown",
  bo = { filetype = "snacks_notif_history", modifiable = false },
  wo = { winhighlight = "Normal:SnacksNotifierHistory" },
  keys = { q = "close" },
}
```

## 📚 Types

Render styles:
* compact: use border for icon and title
* minimal: no border, only icon and message
* fancy: similar to the default nvim-notify style

```lua
---@alias snacks.notifier.style snacks.notifier.render|"compact"|"fancy"|"minimal"
```

### Notifications

Notification options

```lua
---@class snacks.notifier.Notif.opts
---@field id? number|string
---@field msg? string
---@field level? number|snacks.notifier.level
---@field title? string
---@field icon? string
---@field timeout? number|boolean timeout in ms. Set to 0|false to keep until manually closed
---@field ft? string
---@field keep? fun(notif: snacks.notifier.Notif): boolean
---@field style? snacks.notifier.style
---@field opts? fun(notif: snacks.notifier.Notif) -- dynamic opts
---@field hl? snacks.notifier.hl -- highlight overrides
---@field history? boolean
```

Notification object

```lua
---@class snacks.notifier.Notif: snacks.notifier.Notif.opts
---@field id number|string
---@field msg string
---@field win? snacks.win
---@field icon string
---@field level snacks.notifier.level
---@field timeout number
---@field dirty? boolean
---@field added number timestamp with nano precision
---@field updated number timestamp with nano precision
---@field shown? number timestamp with nano precision
---@field hidden? number timestamp with nano precision
---@field layout? { top?: number, width: number, height: number }
```

### Rendering

```lua
---@alias snacks.notifier.render fun(buf: number, notif: snacks.notifier.Notif, ctx: snacks.notifier.ctx)
```

```lua
---@class snacks.notifier.hl
---@field title string
---@field icon string
---@field border string
---@field footer string
---@field msg string
```

```lua
---@class snacks.notifier.ctx
---@field opts snacks.win.Config
---@field notifier snacks.notifier.Class
---@field hl snacks.notifier.hl
---@field ns number
```

### History

```lua
---@class snacks.notifier.history
---@field filter? vim.log.levels|snacks.notifier.level|fun(notif: snacks.notifier.Notif): boolean
---@field sort? string[] # sort fields, default: {"added"}
---@field reverse? boolean
```

```lua
---@alias snacks.notifier.level "trace"|"debug"|"info"|"warn"|"error"
```

## 📦 Module

### `Snacks.notifier()`

```lua
---@type fun(msg: string, level?: snacks.notifier.level|number, opts?: snacks.notifier.Notif.opts): number|string
Snacks.notifier()
```

### `Snacks.notifier.get_history()`

```lua
---@param opts? snacks.notifier.history
Snacks.notifier.get_history(opts)
```

### `Snacks.notifier.hide()`

```lua
---@param id? number|string
Snacks.notifier.hide(id)
```

### `Snacks.notifier.notify()`

```lua
---@param msg string
---@param level? snacks.notifier.level|number
---@param opts? snacks.notifier.Notif.opts
Snacks.notifier.notify(msg, level, opts)
```

### `Snacks.notifier.show_history()`

```lua
---@param opts? snacks.notifier.history
Snacks.notifier.show_history(opts)
```
