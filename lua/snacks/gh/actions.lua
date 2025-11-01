local Api = require("snacks.gh.api")
local config = require("snacks.gh").config()

local M = {}

---@class snacks.gh.action.ctx
---@field items snacks.picker.gh.Item[]
---@field picker? snacks.Picker
---@field action? snacks.picker.Action

---@class snacks.gh.cli.Action.ctx
---@field item snacks.picker.gh.Item
---@field args string[]
---@field opts snacks.gh.cli.Action
---@field picker? snacks.Picker
---@field scratch? snacks.win
---@field input? string

---@alias snacks.gh.action.fn fun(item?: snacks.picker.gh.Item, ctx: snacks.gh.action.ctx)

---@class snacks.gh.Action
---@field action snacks.gh.action.fn
---@field desc? string
---@field name? string
---@field priority? number
---@field title? string -- for items
---@field type? "pr" | "issue"
---@field enabled? fun(item: snacks.picker.gh.Item): boolean

---@class snacks.gh.actions: {[string]:snacks.gh.Action}
M.actions = setmetatable({}, {
  __index = function(_, key)
    if type(key) ~= "string" then
      return nil
    end
    local action = M.cli_actions[key]
    if action then
      local ret = M.cli_action(action)
      rawset(M.actions, key, ret)
      return ret
    end
  end,
})

M.actions.gh_diff = {
  desc = "View PR diff",
  icon = " ",
  priority = 100,
  type = "pr",
  title = "View diff for PR #{number}",
  action = function(item, ctx)
    if not item then
      return
    end
    Snacks.picker.gh_diff({
      show_delay = 0,
      repo = item.repo,
      pr = item.number,
    })
  end,
}

M.actions.gh_open = {
  desc = "Open in buffer",
  icon = " ",
  priority = 100,
  title = "Open {type} #{number} in buffer",
  action = function(item, ctx)
    if ctx.picker then
      return Snacks.picker.actions.jump(ctx.picker, item, ctx.action)
    end
  end,
}

M.actions.gh_actions = {
  desc = "Show available actions",
  action = function(item, ctx)
    -- NOTE: this forwards split/vsplit/tab/drop actions to jump
    if ctx.action and ctx.action.cmd then
      return Snacks.picker.actions.jump(ctx.picker, item, ctx.action)
    end
    local actions = M.get_actions(item)
    actions.gh_actions = nil -- remove self to avoid recursion
    Snacks.picker.pick({
      source = "gh_actions",
      layout = {
        preset = "select",
        layout = { max_width = 80 },
        config = function(layout)
          -- Fit list height to number of items, up to 10
          for _, box in ipairs(layout.layout) do
            if box.win == "list" and not box.height then
              box.height = math.max(math.min(vim.tbl_count(actions), vim.o.lines * 0.8 - 10), 3)
            end
          end
        end,
      },
      main = { current = true },
      title = ("Actions for %s #%d"):format(item.type, item.number),
      finder = function()
        local items = {} ---@type snacks.picker.finder.Item[]
        for name, action in pairs(actions) do
          ---@class snacks.picker.gh.Action: snacks.picker.finder.Item
          items[#items + 1] = {
            text = Snacks.picker.util.text(action, { "name", "desc" }),
            file = item.uri,
            name = name,
            item = item,
            desc = action.desc or name,
            action = action,
          }
        end
        table.sort(items, function(a, b)
          local pa = a.action.priority or 0
          local pb = b.action.priority or 0
          if pa ~= pb then
            return pa > pb
          end
          return a.desc < b.desc
        end)
        return items
      end,
      format = "gh_format_action",
      ---@param it snacks.picker.gh.Action
      confirm = function(picker, it, action)
        if not it then
          return
        end
        ctx.action = action
        if ctx.picker then
          ctx.picker:focus()
        end
        it.action.action(item, ctx)
        picker:close()
      end,
    })
  end,
}

M.actions.gh_browse = {
  desc = "Open in web browser",
  title = "Open {type} #{number} in web browser",
  icon = " ",
  action = function(_, ctx)
    for _, item in ipairs(ctx.items) do
      Api.cmd(function()
        Snacks.notify.info(("Opened #%s in web browser"):format(item.number))
      end, {
        args = { item.type, "view", tostring(item.number), "--web" },
        repo = item.repo,
      })
    end
    if ctx.picker then
      ctx.picker.list:set_selected() -- clear selection
    end
  end,
}

M.actions.gh_react = {
  desc = "Add reaction",
  icon = " ",
  action = function(item, ctx)
    local reactions = { "+1", "-1", "laugh", "hooray", "confused", "heart", "rocket", "eyes" }
    Snacks.picker.pick("gh_reactions", {
      number = item.number,
      repo = item.repo,
      layout = {
        config = function(layout)
          -- Fit list height to number of items, up to 10
          for _, box in ipairs(layout.layout) do
            if box.win == "list" and not box.height then
              box.height = math.max(math.min(#reactions, vim.o.lines * 0.8 - 10), 3)
            end
          end
        end,
      },
      confirm = function(picker)
        local items = picker:selected({ fallback = true })
        for i, it in ipairs(items) do
          if it.added then
            M.run(item, {
              api = {
                endpoint = "/repos/{repo}/issues/{number}/reactions/" .. it.id,
                method = "DELETE",
              },
              refresh = i == #items,
            }, ctx)
          else
            M.run(item, {
              api = {
                endpoint = "/repos/{repo}/issues/{number}/reactions",
                fields = { content = it.reaction },
              },
              refresh = i == #items,
            }, ctx)
          end
        end
        picker:close()
      end,
    })
  end,
}

M.actions.gh_label = {
  desc = "Add/Remove labels",
  icon = "󰌕 ",
  action = function(item, ctx)
    Snacks.picker.pick("gh_labels", {
      number = item.number,
      repo = item.repo,
      type = item.type,
      confirm = function(picker)
        local labels = {} ---@type table<string, boolean>
        for _, label in ipairs(item.item.labels or {}) do
          labels[label.name] = true
        end
        for _, it in ipairs(picker:selected({ fallback = true })) do
          labels[it.label] = not it.added or nil
        end
        M.run(item, {
          api = {
            endpoint = "/repos/{repo}/issues/{number}/labels",
            method = "PUT",
            input = vim.fn.json_encode({ labels = vim.tbl_keys(labels) }),
          },
        }, ctx)
        picker:close()
      end,
    })
  end,
}

M.actions.gh_yank = {
  desc = "Yank URL(s) to clipboard",
  icon = " ",
  action = function(_, ctx)
    if vim.fn.mode():find("^[vV]") and ctx.picker then
      ctx.picker.list:select()
    end
    ---@param it snacks.picker.gh.Item
    local urls = vim.tbl_map(function(it)
      return it.url
    end, ctx.items)
    if ctx.picker then
      ctx.picker.list:set_selected() -- clear selection
    end
    local value = table.concat(urls, "\n")
    vim.fn.setreg(vim.v.register or "+", value, "l")
    Snacks.notify.info("Yanked " .. #urls .. " URL(s)")
  end,
}

---@type table<string, snacks.gh.cli.Action>
M.cli_actions = {
  gh_comment = {
    cmd = "comment",
    icon = " ",
    title = "Comment on {type} #{number}",
    success = "Commented on {type} #{number}",
    edit = "body-file",
  },
  gh_checkout = {
    cmd = "checkout",
    icon = " ",
    type = "pr",
    confirm = "Are you sure you want to checkout PR #{number}?",
    title = "Checkout PR #{number}",
    success = "Checked out PR #{number}",
  },
  gh_close = {
    edit = "comment",
    icon = config.icons.crossmark,
    cmd = "close",
    title = "Close {type} #{number}",
    success = "Closed {type} #{number}",
    enabled = function(item)
      return item.state == "open"
    end,
  },
  gh_edit = {
    cmd = "edit",
    icon = " ",
    fields = {
      { arg = "title", prop = "title", name = "Title" },
    },
    success = "Edited {type} #{number}",
    edit = "body-file",
    template = "{body}",
    title = "Edit {type} #{number}",
  },
  gh_squash = {
    cmd = "merge",
    icon = config.icons.pr.merged,
    type = "pr",
    success = "Squashed and merged PR #{number}",
    args = { "--squash" },
    fields = {
      { arg = "subject", prop = "title", name = "Title" },
    },
    edit = "body-file",
    confirm = "Are you sure you want to squash and merge PR #{number}?",
    template = "{body}",
    title = "Squash and merge PR #{number}",
    enabled = function(item)
      return item.state == "open"
    end,
  },
  gh_merge_rebase = {
    cmd = "merge",
    icon = config.icons.pr.merged,
    type = "pr",
    success = "Rebased and merged PR #{number}",
    args = { "--rebase" },
    confirm = "Are you sure you want to rebase and merge PR #{number}?",
    title = "Rebase and merge PR #{number}",
    enabled = function(item)
      return item.state == "open"
    end,
  },
  gh_merge = {
    cmd = "merge",
    icon = config.icons.pr.merged,
    type = "pr",
    success = "Merged PR #{number}",
    args = { "--merge" },
    title = "Merge PR #{number}",
    confirm = "Are you sure you want to merge PR #{number}?",
    enabled = function(item)
      return item.state == "open"
    end,
  },
  gh_close_not_planned = {
    cmd = "close",
    icon = config.icons.crossmark,
    type = "issue",
    success = "Closed issue #{number} as not planned",
    args = { "--reason", "not planned" },
    edit = "comment",
    title = "Close issue #{number} as not planned",
    enabled = function(item)
      return item.state == "open"
    end,
  },
  gh_reopen = {
    cmd = "reopen",
    icon = " ",
    edit = "comment",
    title = "Reopen {type} #{number}",
    success = "Reopened {type} #{number}",
    enabled = function(item)
      return item.state == "closed"
    end,
  },
  gh_ready = {
    cmd = "ready",
    icon = config.icons.pr.open,
    type = "pr",
    title = "Mark PR #{number} as ready for review",
    success = "Marked PR #{number} as ready for review",
    enabled = function(item)
      return item.state == "open" and item.isDraft
    end,
  },
  gh_draft = {
    cmd = "ready",
    args = { "--undo" },
    icon = config.icons.pr.draft,
    type = "pr",
    title = "Mark PR #{number} as draft",
    success = "Marked PR #{number} as draft",
    enabled = function(item)
      return item.state == "open" and not item.isDraft
    end,
  },
  gh_approve = {
    cmd = "review",
    icon = config.icons.checkmark,
    type = "pr",
    args = { "--approve" },
    edit = "body-file", -- optional review summary
    title = "Review: approve PR #{number}",
    success = "Approved PR #{number}",
    enabled = function(item)
      return item.state == "open"
    end,
  },
  gh_request_changes = {
    cmd = "review",
    type = "pr",
    icon = " ",
    args = { "--request-changes" },
    edit = "body-file", -- explain what needs fixing
    title = "Review: request changes on PR #{number}",
    success = "Requested changes on PR #{number}",
    enabled = function(item)
      return item.state == "open"
    end,
  },
  gh_review = {
    cmd = "review",
    type = "pr",
    icon = " ",
    args = { "--comment" },
    edit = "body-file", -- general feedback
    title = "Review: comment on PR #{number}",
    success = "Commented on PR #{number}",
    enabled = function(item)
      return item.state == "open"
    end,
  },
}

---@param opts snacks.gh.cli.Action
function M.cli_action(opts)
  ---@type snacks.gh.Action
  return setmetatable({
    desc = opts.desc or opts.title,
    ---@type snacks.gh.action.fn
    action = function(item, ctx)
      M.run(item, opts, ctx)
    end,
  }, { __index = opts })
end

---@param str string
---@param ... table<string, any>
function M.tpl(str, ...)
  local data = { ... }
  return Snacks.picker.util.tpl(
    str,
    setmetatable({}, {
      __index = function(_, key)
        for _, d in ipairs(data) do
          if d[key] ~= nil then
            local ret = d[key]
            return ret == "pr" and "PR" or ret
          end
        end
      end,
    })
  )
end

---@param item snacks.picker.gh.Item
function M.get_actions(item)
  local ret = {} ---@type table<string, snacks.gh.Action>
  local keys = vim.tbl_keys(M.actions) ---@type string[]
  vim.list_extend(keys, vim.tbl_keys(M.cli_actions))
  for _, name in ipairs(keys) do
    local action = M.actions[name]
    local enabled = action.type == nil or action.type == item.type
    enabled = enabled and (action.enabled == nil or action.enabled(item))
    if enabled then
      local a = setmetatable({}, { __index = action })
      local ca = M.cli_actions[name] or {}
      a.desc = a.title and M.tpl(a.title or name, item, ca) or a.desc
      a.name = name
      ret[name] = a
    end
  end
  return ret
end

--- Executes a gh cli action
---@param item snacks.picker.gh.Item
---@param action snacks.gh.cli.Action
---@param ctx snacks.gh.action.ctx
function M.run(item, action, ctx)
  local args = action.cmd and { item.type, action.cmd, tostring(item.number) } or {}
  vim.list_extend(args, action.args or {})
  if action.api then
    action.api.endpoint = M.tpl(action.api.endpoint, item, action)
  end
  ---@type snacks.gh.cli.Action.ctx
  local cli_ctx = {
    item = item,
    args = args,
    opts = action,
    picker = ctx.picker,
  }
  if action.edit then
    return M.edit(cli_ctx)
  else
    return M._run(cli_ctx)
  end
end

--- Parses frontmatter fields from body and appends them to ctx.args
---@param body string
---@param ctx snacks.gh.cli.Action.ctx
function M.parse(body, ctx)
  if not ctx.opts.fields then
    return body
  end

  local fields = {} ---@type table<string, snacks.gh.Field>
  for _, f in ipairs(ctx.opts.fields) do
    fields[f.name] = f
  end

  local values = {} ---@type table<string, string>
  --- parse markdown frontmatter for fields
  body = body:gsub("^(%-%-%-\n.-\n%-%-%-\n%s*)", function(fm)
    fm = fm:gsub("^%-%-%-\n", ""):gsub("\n%-%-%-\n%s*$", "") --[[@as string]]
    local lines = vim.split(fm, "\n")
    for _, line in ipairs(lines) do
      local field, value = line:match("^(%w+):%s*(.-)%s*$")
      if field and fields[field] then
        values[field] = value
      else
        Snacks.notify.warn(("Unknown field `%s` in frontmatter"):format(field or line))
      end
    end
    return ""
  end) --[[@as string]]

  for _, field in ipairs(ctx.opts.fields) do
    local value = values[field.name]
    if value then
      if ctx.opts.api then
        ctx.opts.api.fields = ctx.opts.api.fields or {}
        ctx.opts.api.fields[field.arg] = value
      else
        vim.list_extend(ctx.args, { "--" .. field.arg, value })
      end
    else
      Snacks.notify.error(("Missing required field `%s` in frontmatter"):format(field.name))
      return
    end
  end
  return body
end

--- Executes the action CLI command
---@param ctx snacks.gh.cli.Action.ctx
function M._run(ctx, force)
  if not force and ctx.opts.confirm then
    Snacks.picker.util.confirm(M.tpl(ctx.opts.confirm, ctx.item, ctx.opts), function()
      M._run(ctx, true)
    end)
    return
  end

  local spinner = require("snacks.picker.util.spinner").loading()
  local cb = function()
    vim.schedule(function()
      spinner:stop()

      -- success message
      if ctx.opts.success then
        Snacks.notify.info(M.tpl(ctx.opts.success, ctx.item, ctx.opts))
      end

      -- refresh item and picker
      if ctx.opts.refresh ~= false then
        vim.schedule(function()
          Api.refresh(ctx.item)
          if ctx.picker and not ctx.picker.closed then
            ctx.picker.list:set_selected()
            ctx.picker.list:set_target()
            ctx.picker:find()
            vim.cmd.startinsert()
          end
        end)
        if ctx.picker and not ctx.picker.closed then
          ctx.picker:focus()
        end
      end

      -- clean up scratch buffer
      if ctx.scratch then
        local buf = assert(ctx.scratch.buf)
        local fname = vim.api.nvim_buf_get_name(buf)
        ctx.scratch:on("WinClosed", function()
          vim.schedule(function()
            pcall(vim.api.nvim_buf_delete, buf, { force = true })
            os.remove(fname)
            os.remove(fname .. ".meta")
          end)
        end, { buf = true })
        ctx.scratch:close()
      end
    end)
  end

  if ctx.opts.api then
    Api.request(
      cb,
      Snacks.config.merge(ctx.opts.api or {}, {
        input = ctx.input,
        args = ctx.args,
        on_error = function()
          spinner:stop()
        end,
      })
    )
  else
    Api.cmd(cb, {
      input = ctx.input,
      args = ctx.args,
      repo = ctx.item.repo or ctx.opts.repo,
      on_error = function()
        spinner:stop()
      end,
    })
  end
end

--- Edit action body in scratch buffer
---@param ctx snacks.gh.cli.Action.ctx
function M.edit(ctx)
  ---@param s? string
  local function tpl(s)
    return s and M.tpl(s, ctx.item, ctx.opts) or nil
  end

  local template = ctx.opts.template or ""
  if not vim.tbl_isempty(ctx.opts.fields or {}) then
    local fm = { "---" }
    for _, f in ipairs(ctx.opts.fields) do
      fm[#fm + 1] = ("%s: {%s}"):format(f.name, f.prop)
    end
    fm[#fm + 1] = "---\n\n"
    template = table.concat(fm, "\n") .. template
  end

  Snacks.scratch({
    ft = "markdown",
    icon = Snacks.gh.config().icons.logo,
    name = tpl(ctx.opts.title or "{cmd} {type} #{number}"),
    template = tpl(template),
    filekey = {
      cwd = false,
      branch = false,
      count = false,
      id = tpl("{repo}/{type}/{cmd}"),
    },
    win = {
      on_win = function()
        vim.schedule(function()
          vim.cmd.startinsert()
        end)
      end,
      keys = {
        submit = {
          "<c-s>",
          function(win)
            ctx.scratch = win
            M.submit(ctx)
          end,
          desc = "Submit",
          mode = { "n", "i" },
        },
      },
    },
  })
end

--- Submit edited body
---@param ctx snacks.gh.cli.Action.ctx
function M.submit(ctx)
  local edit = assert(ctx.opts.edit, "Submit called for action that doesn't need edit?")
  local win = assert(ctx.scratch, "Submit not called from scratch window?")
  ctx = setmetatable({
    args = vim.deepcopy(ctx.args),
  }, { __index = ctx }) -- shallow copy to avoid mutation
  local body = M.parse(win:text(), ctx)

  if not body then
    return -- error already shown in M.parse
  end

  if body:find("%S") then
    if edit == "body-file" then
      vim.list_extend(ctx.args, { "--body-file", "-" })
      ctx.input = body
    else
      vim.list_extend(ctx.args, { "--" .. edit, body })
    end
  end

  vim.cmd.stopinsert()
  vim.schedule(function()
    M._run(ctx)
  end)
end

return M
