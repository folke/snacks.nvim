local Api = require("snacks.gh.api")
local config = require("snacks.gh").config()

local M = {}

---@class snacks.gh.action.ctx
---@field items snacks.picker.gh.Item[]
---@field picker? snacks.Picker
---@field main? number
---@field action? snacks.picker.Action

---@class snacks.gh.cli.Action.ctx
---@field item snacks.picker.gh.Item
---@field args string[]
---@field opts snacks.gh.cli.Action
---@field picker? snacks.Picker
---@field scratch? snacks.win
---@field main? number
---@field input? string

---@alias snacks.gh.action.fn fun(item?: snacks.picker.gh.Item, ctx: snacks.gh.action.ctx)

---@class snacks.gh.Action
---@field action snacks.gh.action.fn
---@field desc? string
---@field name? string
---@field priority? number
---@field title? string -- for items
---@field type? "pr" | "issue"
---@field enabled? fun(item: snacks.picker.gh.Item, ctx: snacks.gh.action.ctx): boolean

---@param item snacks.picker.gh.Item
---@param ctx snacks.gh.action.ctx
local function update_main(item, ctx)
  local gh = { repo = item.repo, number = item.number, type = item.type }
  if ctx.main and vim.api.nvim_win_is_valid(ctx.main) then
    local buf = vim.api.nvim_win_get_buf(ctx.main)
    if vim.deep_equal(vim.b[buf].snacks_gh or {}, gh) then
      return ctx.main, buf
    end
  end
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.deep_equal(vim.b[buf].snacks_gh or {}, gh) then
    ctx.main = win
    return ctx.main, buf
  end
end

---@param item snacks.picker.gh.Item
---@param ctx snacks.gh.action.ctx
local function get_meta(item, ctx)
  local win, buf = update_main(item, ctx)
  if not win or not buf then
    return
  end
  local meta = Snacks.picker.highlight.meta(buf)
  ---@type {comment_id?: number, diff?: snacks.diff.Meta}?
  local m = meta and meta[vim.api.nvim_win_get_cursor(win)[1]] or nil
  return m, meta, buf, win
end

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
    update_main(item, ctx)
    local actions = M.get_actions(item, ctx)
    actions.gh_actions = nil -- remove this action
    actions.gh_perform_action = nil -- remove this action
    Snacks.picker.gh_actions({
      item = item,
      layout = {
        config = function(layout)
          -- Fit list height to number of items, up to 10
          for _, box in ipairs(layout.layout) do
            if box.win == "list" and not box.height then
              box.height = math.max(math.min(vim.tbl_count(actions), vim.o.lines * 0.8 - 10), 3)
            end
          end
        end,
      },
      ---@param it snacks.picker.gh.Action
      confirm = function(picker, it, action)
        if not it then
          return
        end
        ctx.action = action
        if ctx.picker then
          ctx.picker.visual = ctx.picker.visual or picker.visual or nil
          ctx.picker:focus()
        end
        update_main(item, ctx)
        it.action.action(item, ctx)
        picker:close()
      end,
    })
  end,
}

M.actions.gh_perform_action = {
  action = function(item, ctx)
    if not item then
      return
    end
    -- pass a new context, since we're doing the action on a single item
    item.action.action(item.item, { items = { item.item } })
    ctx.picker:close()
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
            input = { labels = vim.tbl_keys(labels) },
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

M.actions.gh_reply_to_comment = {
  desc = "Reply to comment",
  title = "Reply to comment on {type} #{number}",
  priority = 150,
  icon = " ",
  enabled = function(item, ctx)
    local m = get_meta(item, ctx)
    return m and m.comment_id ~= nil or false
  end,
  action = function(item, ctx)
    local action = vim.deepcopy(M.cli_actions.gh_comment)
    local m = get_meta(item, ctx)
    if not (m and m.comment_id) then
      Snacks.notify.error("No comment found to reply to")
      return
    end
    action.title = "Reply to comment on {type} #{number}"
    action.api = {
      endpoint = "/repos/{repo}/pulls/{number}/comments",
      input = { in_reply_to = m.comment_id },
    }
    M.run(item, action, ctx)
  end,
}

M.actions.gh_diff_comment = {
  desc = "Add diff comment",
  title = "Comment on diff in {type} #{number}",
  priority = 150,
  icon = " ",
  enabled = function(item, ctx)
    local m = get_meta(item, ctx)
    return m and m.diff ~= nil or false
  end,
  action = function(item, ctx)
    local m, meta, buf = get_meta(item, ctx)
    if not (meta and buf and m and m.diff) then
      Snacks.notify.error("No diff hunk found to comment on")
      return
    end

    local action = vim.deepcopy(M.cli_actions.gh_comment)
    local visual = ctx.picker and ctx.picker.visual or Snacks.picker.util.visual()
    visual = visual and visual.buf == buf and visual or nil
    local line = m.diff.line ---@type number
    local start_line ---@type number?
    if visual then
      local from, to = math.min(visual.pos[1], visual.end_pos[1]), math.max(visual.pos[1], visual.end_pos[1])
      local line_diff = vim.tbl_get(meta, to, "diff") or m.diff --[[@as snacks.diff.Meta]]
      local start_diff = vim.tbl_get(meta, from, "diff") or m.diff --[[@as snacks.diff.Meta]]
      if line_diff.file ~= start_diff.file then
        Snacks.notify.error("Cannot add comment: visual selection spans multiple files")
        return
      end
      local code = {} ---@type string[]
      for i = from, to do
        code[#code + 1] = vim.tbl_get(meta, i, "diff", "code") or ""
      end
      line, start_line = line_diff.line, start_diff.line
      local ft = vim.filetype.match({ filename = m.diff.file }) or ""
      local code_header = "```" .. (ft == "" and "" or (ft .. " ")) .. "suggestion\n"
      action.template = ("\n%s%s\n```\n"):format(code_header, table.concat(code, "\n"))
      action.on_submit = function(body)
        local s, e = body:find(action.template, 1, true)
        if s and e then -- suggestion not edited, so remove it
          body = body:sub(1, s - 1) .. body:sub(e + 1)
        end
        body = body:gsub(code_header, "```suggestion\n") -- remove ft from suggestion
        return body
      end
    end
    start_line = start_line ~= line and start_line or nil
    if start_line then
      action.title = ("Comment on lines %s%d to %s%d"):format(
        m.diff.side:sub(1, 1):upper(),
        start_line or line,
        m.diff.side:sub(1, 1):upper(),
        line
      )
    else
      action.title = ("Comment on line %s%d"):format(m.diff.side:sub(1, 1):upper(), line)
    end
    action.api = {
      endpoint = "/repos/{repo}/pulls/{number}/comments",
      input = {
        commit_id = item.headRefOid,
        path = m.diff.file,
        side = m.diff.side:upper(), -- "RIGHT" or "LEFT" (uppercase)
        line = line,
        start_line = start_line,
      },
    }
    if item.pendingReview then
      action.api = {
        endpoint = "graphql",
        input = {
          -- inject: graphql
          query = [[
            mutation($reviewId: ID!, $body: String!, $path: String!, $line: Int!, $side: DiffSide!, $startLine: Int, $startSide: DiffSide) {
              addPullRequestReviewThread(input: {
                pullRequestReviewId: $reviewId
                body: $body
                path: $path
                line: $line
                side: $side
                startLine: $startLine
                startSide: $startSide
              }) {
                thread { id }
              }
            }
          ]],
          variables = {
            reviewId = item.pendingReview.id,
            path = m.diff.file,
            side = m.diff.side:upper(), -- "RIGHT" or "LEFT"
            line = line,
            startLine = start_line,
            startSide = start_line and m.diff.side:upper() or nil,
          },
        },
      }
    end
    M.run(item, action, ctx)
  end,
}

M.actions.gh_comment = {
  desc = "Add comment",
  title = "Comment on {type} #{number}",
  icon = " ",
  action = function(item, ctx)
    local m = get_meta(item, ctx)
    if m and m.comment_id then
      return M.actions.gh_reply_to_comment.action(item, ctx)
    elseif m and m.diff then
      return M.actions.gh_diff_comment.action(item, ctx)
    end
    local action = vim.deepcopy(M.cli_actions.gh_comment)
    M.run(item, action, ctx)
  end,
}

M.actions.gh_update_branch = {
  icon = "󰚰 ",
  title = "Update branch of PR #{number}",
  type = "pr",
  enabled = function(item)
    return item.state == "open"
  end,
  action = function(item, ctx)
    Snacks.picker.select(
      { "1. Yes using the rebase method", "2. Yes using the merge method", "3. Cancel" },
      { title = "Are you sure you want to update the brnch of PR #" .. item.id .. "?" },
      function(choice, idx)
        if idx == 3 then
          return
        end

        local action = vim.deepcopy(M.cli_actions.gh_update_branch)
        if idx == 1 then
          action.args = { "--rebase" }
        end
        M.run(item, action, ctx)
      end
    )
  end,
}

-- Start a new review
M.actions.gh_start_review = {
  desc = "Start a review",
  type = "pr",
  icon = " ",
  priority = 100,
  enabled = function(item)
    return item.pendingReview == nil
  end,
  action = function(item, ctx)
    M.run(item, {
      api = {
        endpoint = "/repos/{repo}/pulls/{number}/reviews",
        input = { commit_id = item.headRefOid },
      },
      success = "Started pending review for PR #{number}",
    }, ctx)
  end,
}

-- Submit pending review
M.actions.gh_submit_review = {
  desc = "Submit pending review",
  type = "pr",
  icon = " ",
  priority = 200,
  enabled = function(item)
    return item.pendingReview ~= nil
  end,
  action = function(item, ctx)
    local review_id = item.pendingReview.databaseId

    -- Ask user: APPROVE, REQUEST_CHANGES, or COMMENT
    Snacks.picker.select(
      { "Approve", "Request Changes", "Comment" },
      { title = "Submit review for PR #" .. item.number },
      function(choice, idx)
        if not choice then
          return
        end
        local events = { "APPROVE", "REQUEST_CHANGES", "COMMENT" }
        M.run(item, {
          title = "Submit review for PR #{number}",
          api = {
            endpoint = "/repos/{repo}/pulls/{number}/reviews/" .. review_id .. "/events",
            input = { event = events[idx] },
          },
          edit = "body-file", -- Optional summary
          success = "Submitted review for PR #{number}",
        }, ctx)
      end
    )
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
  gh_update_branch = {
    cmd = "update-branch",
    title = "Update branch of PR #{number}",
    success = "Branch of PR #{number} updated",
    type = "pr",
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
      return item.state == "open" and not item.pendingReview
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
      return item.state == "open" and not item.pendingReview
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
      return item.state == "open" and not item.pendingReview
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
---@param ctx snacks.gh.action.ctx
function M.get_actions(item, ctx)
  local ret = {} ---@type table<string, snacks.gh.Action>
  local keys = vim.tbl_keys(M.actions) ---@type string[]
  vim.list_extend(keys, vim.tbl_keys(M.cli_actions))
  for _, name in ipairs(keys) do
    local action = M.actions[name]
    local enabled = action.type == nil or action.type == item.type
    enabled = enabled and (action.enabled == nil or action.enabled(item, ctx))
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
    main = ctx.main,
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
            ctx.picker:refresh()
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

  local preview = ctx.picker and ctx.picker.preview and ctx.picker.preview.win:valid() and ctx.picker.preview.win or nil
  local actions = preview and preview.opts.actions or {}
  local parent = ctx.main or preview and preview.win or vim.api.nvim_get_current_win()

  local height = config.scratch.height or 15
  local opts = Snacks.win.resolve({
    relative = "win",
    width = 0,
    backdrop = false,
    height = height,
    actions = {
      cycle_win = actions.cycle_win,
      preview_scroll_up = actions.preview_scroll_up,
      preview_scroll_down = actions.preview_scroll_down,
    },
    win = parent,
    wo = { winhighlight = "NormalFloat:Normal,FloatTitle:SnacksGhScratchTitle,FloatBorder:SnacksGhScratchBorder" },
    border = "top_bottom",
    row = function(win)
      local border = win:border_size()
      return win:parent_size().height - height - border.top - border.bottom
    end,
    on_win = function(win)
      if vim.api.nvim_win_is_valid(parent) then
        local parent_row = vim.api.nvim_win_call(parent, vim.fn.winline) ---@type number
        parent_row = parent_row + vim.wo[parent].scrolloff -- adjust for scrolloff
        local row = vim.api.nvim_win_get_height(parent) - win:size().height
        if parent_row > row then
          vim.api.nvim_win_call(parent, function()
            vim.cmd(("normal! %d%s"):format(parent_row - row, Snacks.util.keycode("<C-e>")))
          end)
        end
      end
      vim.g.snacks_picker_cycle_win = win.win
      vim.schedule(function()
        vim.cmd.startinsert()
      end)
    end,
    footer_keys = { "<c-s>", "R" },
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
  }, preview and {
    keys = {
      ["<a-w>"] = { "cycle_win", mode = { "i", "n" } },
      ["<c-b>"] = { "preview_scroll_up", mode = { "i", "n" } },
      ["<c-f>"] = { "preview_scroll_down", mode = { "i", "n" } },
    },
  } or nil)
  Snacks.scratch({
    ft = "markdown",
    icon = config.icons.logo,
    name = tpl(ctx.opts.title or "{cmd} {type} #{number}"),
    template = tpl(template),
    filekey = {
      cwd = false,
      branch = false,
      count = false,
      id = tpl("{repo}/{type}/{cmd}"),
    },
    win = opts,
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

  if ctx.opts.on_submit then
    body = ctx.opts.on_submit(body, ctx) or body
  end

  if body:find("%S") then
    if edit == "body-file" then
      if ctx.opts.api then
        ctx.opts.api.input = ctx.opts.api.input or {}
        if ctx.opts.api.input.variables then
          ctx.opts.api.input.variables.body = body
        else
          ctx.opts.api.input.body = body
        end
      else
        ctx.input = body
        vim.list_extend(ctx.args, { "--body-file", "-" })
      end
    else
      if ctx.opts.api then
        ctx.opts.api.fields = ctx.opts.api.fields or {}
        ctx.opts.api.fields[edit] = body
      else
        vim.list_extend(ctx.args, { "--" .. edit, body })
      end
    end
  end

  vim.cmd.stopinsert()
  vim.schedule(function()
    M._run(ctx)
  end)
end

return M
