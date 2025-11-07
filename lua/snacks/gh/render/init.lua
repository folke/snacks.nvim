local Markdown = require("snacks.picker.util.markdown")

local M = {}
local h = Snacks.picker.highlight
local extend = h.extend
local util = Snacks.picker.util

-- tracking comment_skip is needed because review comments can appear both:
-- 1. As top-level review.comments
-- 2. As replies in the thread tree
---@class snacks.gh.render.ctx
---@field item snacks.picker.gh.Item
---@field opts snacks.gh.Config
---@field comment_skip table<string, boolean>
---@field is_review? boolean
---@field diff? boolean render diffs (defaults to true)
---@field markdown? boolean render in a markdown buffer (defaults to true)
---@field annotations? snacks.diff.Annotation[]

---@param field string
local function time_prop(field)
  return {
    name = util.title(field),
    hl = function(item)
      if not item[field] then
        return
      end
      return { { util.reltime(item[field]), "SnacksPickerGitDate" } }
    end,
  }
end

---@type {name: string, hl:fun(item:snacks.picker.gh.Item, opts:snacks.gh.Config):snacks.picker.Highlight[]? }[]
M.props = {
  {
    name = "Status",
    hl = function(item, opts)
      -- Status Icon
      local icons = opts.icons[item.type]
      local status = icons[item.status] and item.status or "other"
      local ret = {} ---@type snacks.picker.Highlight[]
      if status then
        local icon = icons[status]
        local hl = "SnacksGh" .. util.title(item.type) .. util.title(status)
        local text = icon .. util.title(item.status or "other")
        extend(ret, h.badge(text, { bg = Snacks.util.color(hl), fg = "#ffffff" }))
      end
      if item.baseRefName and item.headRefName then
        ret[#ret + 1] = { " " }
        vim.list_extend(ret, {
          { item.baseRefName, "SnacksGhBranch" },
          { " ← ", "SnacksGhDelim" },
          { item.headRefName, "SnacksGhBranch" },
        })
      end
      return ret
    end,
  },
  {
    name = "Repo",
    hl = function(item, opts)
      return { { opts.icons.logo, "Special" }, { item.repo, "@markup.link" } }
    end,
  },
  {
    name = "Author",
    hl = function(item, opts)
      return h.badge(opts.icons.user .. " " .. item.author, "SnacksGhUserBadge")
    end,
  },
  time_prop("created"),
  time_prop("updated"),
  time_prop("closed"),
  time_prop("merged"),
  {
    name = "Reactions",
    hl = function(item, opts)
      if item.reactions then
        local ret = {} ---@type snacks.picker.Highlight[]
        table.sort(item.reactions, function(a, b)
          return a.count > b.count
        end)
        for _, r in pairs(item.reactions) do
          local badge = h.badge(opts.icons.reactions[r.content] .. " " .. tostring(r.count), "SnacksGhReactionBadge")
          vim.list_extend(ret, badge)
          ret[#ret + 1] = { " " }
        end
        return ret
      end
    end,
  },
  {
    name = "Labels",
    hl = function(item)
      local ret = {} ---@type snacks.picker.Highlight[]
      for _, label in ipairs(item.item.labels or {}) do
        local color = label.color or "888888"
        local badge = h.badge(label.name, "#" .. color)
        extend(ret, badge)
        ret[#ret + 1] = { " " }
      end
      return ret
    end,
  },
  {
    name = "Assignees",
    hl = function(item)
      local ret = {} ---@type snacks.picker.Highlight[]
      for _, u in ipairs(item.item.assignees or {}) do
        local badge = h.badge(u.login, "Identifier")
        vim.list_extend(ret, badge)
        ret[#ret + 1] = { " " }
      end
      return ret
    end,
  },
  {
    name = "Milestone",
    hl = function(item)
      if item.item.milestone then
        return h.badge(item.item.milestone.title, "Title")
      end
    end,
  },
  {
    name = "Merge Status",
    hl = function(item, opts)
      if not item.mergeStateStatus or item.state ~= "open" then
        return
      end
      local status = item.mergeStateStatus:lower()
      status = opts.icons.merge_status[status] and status or "dirty"
      local icon = opts.icons.merge_status[status]
      status = util.title(status)
      local hl = "SnacksGhPr" .. status
      return { { icon .. " " .. status, hl } }
    end,
  },
  {
    name = "Checks",
    hl = function(item, opts)
      if item.type ~= "pr" then
        return
      end
      if #(item.statusCheckRollup or {}) == 0 then
        return { { " " } }
      end
      local workflows = {} ---@type table<string, string>
      for _, check in ipairs(item.statusCheckRollup or {}) do
        local status, name = nil, nil ---@type string, string
        if check.__typename == "CheckRun" then
          name = check.workflowName .. ":" .. check.name
          status = check.status == "COMPLETED" and (check.conclusion or "pending") or check.status
        elseif check.__typename == "StatusContext" then
          name = check.context
          status = check.state
        end
        if name and status then
          status = util.title(status:lower())
          workflows[name] = status
        end
      end
      local stats = {} ---@type table<string, number>
      for _, status in pairs(workflows) do
        stats[status] = (stats[status] or 0) + 1
      end
      local ret = {} ---@type snacks.picker.Highlight[]
      local order = { "Success", "Failure", "Pending", "Skipped" }
      for _, status in ipairs(order) do
        local count = stats[status]
        if count then
          local icon = opts.icons.checks[status:lower()] or opts.icons.checks["pending"]
          local badge = h.badge(icon .. " " .. tostring(count), "SnacksGhCheck" .. status)
          vim.list_extend(ret, badge)
          ret[#ret + 1] = { " " }
        end
      end
      ret[#ret + 1] = { " " }
      for _, status in ipairs(order) do
        local count = stats[status]
        if count then
          ret[#ret + 1] = { string.rep(opts.icons.block, count), "SnacksGhCheck" .. status }
        end
      end
      return ret
    end,
  },
  {
    name = "Mergeable",
    hl = function(item, opts)
      if not item.mergeable then
        return
      end
      return {
        {
          (item.mergeable and opts.icons.checkmark or opts.icons.crossmark),
          item.mergeable and "SnacksGhPrClean" or "SnacksGhPrDirty",
        },
      } or nil
    end,
  },
  {
    name = "Changes",
    hl = function(item, opts)
      if item.type ~= "pr" then
        return
      end
      local ret = {} ---@type snacks.picker.Highlight[]

      if item.changedFiles then
        ret = h.badge(opts.icons.file .. item.changedFiles, "SnacksGhStatBadge")
        ret[#ret + 1] = { " " }
      end

      if (item.additions or 0) > 0 then
        ret[#ret + 1] = { "+" .. tostring(item.additions), "SnacksGhAdditions" }
        ret[#ret + 1] = { " " }
      end
      if (item.deletions or 0) > 0 then
        ret[#ret + 1] = { "-" .. tostring(item.deletions), "SnacksGhDeletions" }
        ret[#ret + 1] = { " " }
      end
      if #ret == 0 then
        return
      end

      if item.additions and item.deletions then
        local unit = math.ceil((item.additions + item.deletions) / 5)
        local additions = math.floor((0.5 + item.additions) / unit)
        local deletions = math.floor((0.5 + item.deletions) / unit)
        local neutral = 5 - additions - deletions

        ret[#ret + 1] = { string.rep(opts.icons.block, additions), "SnacksGhAdditions" }
        ret[#ret + 1] = { string.rep(opts.icons.block, deletions), "SnacksGhDeletions" }
        ret[#ret + 1] = { string.rep(opts.icons.block, neutral), "SnacksGhStat" }
      end

      return ret
    end,
  },
}

local ns = vim.api.nvim_create_namespace("snacks.gh.render")

---@param buf number
---@param item snacks.picker.gh.Item
---@param opts snacks.gh.Config|{partial?:boolean}
function M.render(buf, item, opts)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  ---@type snacks.gh.render.ctx
  local ctx = {
    item = item,
    opts = opts,
    comment_skip = {},
  }

  local lines = {} ---@type snacks.picker.Highlight[][]

  item.msg = item.title
  ---@diagnostic disable-next-line: missing-fields
  lines[#lines + 1] = Snacks.picker.format.commit_message(item, {})
  vim.list_extend(lines[#lines], { { " " }, { item.hash, "SnacksPickerDimmed" } }) -- space after title
  lines[#lines + 1] = {} -- empty line

  for _, prop in ipairs(M.props) do
    local value = prop.hl(item, opts)
    if value and #value > 0 then
      local line = {} ---@type snacks.picker.Highlight[]
      line[#line + 1] = { prop.name, "SnacksGhLabel" }
      line[#line + 1] = { ":", "SnacksGhDelim" }
      line[#line + 1] = { " " }
      extend(line, value)
      lines[#lines + 1] = line
    end
  end

  lines[#lines + 1] = {} -- empty line
  lines[#lines + 1] = { { "---", "@punctuation.special.markdown" } }
  lines[#lines + 1] = {} -- empty line

  do
    local text = item.body or ""
    text = text:gsub("<%!%-%-.-%-%->%s*", "") -- remove html comments
    local body = vim.split(text or "", "\n")
    while #body > 0 and body[1]:match("^%s*$") do
      table.remove(body, 1)
    end
    for _, l in ipairs(body) do
      lines[#lines + 1] = { { l } }
    end
  end

  local threads = M.get_threads(item)
  if #threads > 0 then
    lines[#lines + 1] = { { "" } } -- empty line
    lines[#lines + 1] = { { "---", "@punctuation.special.markdown" } }
    lines[#lines + 1] = {} -- empty line

    for _, thread in ipairs(threads) do
      local c = #lines

      ctx.is_review = thread.state ~= nil
      if ctx.is_review then
        ---@cast thread snacks.gh.Review
        vim.list_extend(lines, M.review(thread, ctx))
      else
        ---@cast thread snacks.gh.Comment
        vim.list_extend(lines, M.comment(thread, ctx))
      end

      if #lines > c then -- only add separator if there were comments added
        lines[#lines + 1] = {} -- empty line
      end
    end
  end

  local changed = h.render(buf, ns, lines)

  if changed then
    Markdown.render(buf)
  end

  vim.schedule(function()
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      vim.api.nvim_win_call(win, function()
        if vim.wo.foldmethod == "expr" then
          vim.wo.foldmethod = "expr"
        end
      end)
    end
  end)
end

---@param item snacks.picker.gh.Item
function M.get_threads(item)
  local ret = {} ---@type snacks.gh.Thread[]
  vim.list_extend(ret, item.comments or {})
  vim.list_extend(ret, item.reviews or {})
  table.sort(ret, function(a, b)
    return a.created < b.created
  end)
  return ret
end

---@param comment snacks.gh.Comment|snacks.gh.Review
---@param opts? {text?:string}
---@param ctx snacks.gh.render.ctx
function M.comment_header(comment, opts, ctx)
  opts = opts or {}
  local ret = {} ---@type snacks.picker.Highlight[]
  local is_bot = comment.author.login == "github-actions"
  extend(
    ret,
    h.badge(
      ("%s %s"):format(is_bot and ctx.opts.icons.logo or ctx.opts.icons.user, comment.author.login),
      is_bot and "SnacksGhBotBadge" or "SnacksGhUserBadge"
    )
  )

  if opts.text then
    ret[#ret + 1] = { opts.text, "SnacksGhCommentAction" }
    ret[#ret + 1] = { " " }
  end
  ret[#ret + 1] = { util.reltime(comment.created), "SnacksPickerGitDate" }
  local assoc = comment.authorAssociation
  assoc = assoc and assoc ~= "NONE" and util.title(assoc:lower()) or nil
  assoc = comment.author.login == ctx.item.author and "Author" or assoc
  if assoc then
    ret[#ret + 1] = { " " }
    extend(
      ret,
      h.badge(
        assoc,
        assoc == "Author" and "SnacksGhAuthorBadge" or assoc == "Owner" and "SnacksGhOwnerBadge" or "SnacksGhAssocBadge"
      )
    )
  end
  for _, r in ipairs(comment.reactionGroups or {}) do
    ret[#ret + 1] = { " " }
    local badge = h.badge(
      ctx.opts.icons.reactions[r.content:lower()] .. " " .. tostring(r.users.totalCount),
      "SnacksGhReactionBadge"
    )
    extend(ret, badge)
  end
  return ret
end

---@param item snacks.gh.Comment|snacks.gh.Review
---@param ctx snacks.gh.render.ctx
function M.comment_body(item, ctx)
  local body = item.body or ""
  if body:match("^%s*$") then
    return {}
  end
  local ret = {} ---@type snacks.picker.Highlight[][]
  for _, l in ipairs(vim.split(body, "\n", { plain = true })) do
    if l:find("^```suggestion$") then
      local ft = item.path and vim.filetype.match({ filename = item.path }) or ""
      l = "```" .. ft
      ret[#ret + 1] = h.badge("Suggested change", "SnacksGhSuggestionBadge")
    end
    ret[#ret + 1] = { { l } }
  end
  return ret
end

---@param lines snacks.picker.Highlight[][]
---@param ctx snacks.gh.render.ctx
function M.indent(lines, ctx)
  -- indent guides for lines after the first
  local indent = {} ---@type snacks.picker.Highlight[]
  indent[#indent + 1] = { "   ", "Normal" }
  indent[#indent + 1] = {
    col = 0,
    virt_text = {
      { " ", "Normal" },
      { "┃", { "Normal", "@punctuation.definition.blockquote.markdown" } },
      { " ", "Normal" },
    },
    virt_text_pos = "overlay",
    hl_mode = "combine",
    virt_text_repeat_linebreak = true,
  }

  --- first indent. In a markdown buffer, we need proper structure,
  --- so we conceal the list marker
  ---@type snacks.picker.Highlight[]
  local first = ctx.markdown == false and {}
    or {
      {
        col = 0,
        end_col = 3,
        conceal = "",
        priority = 1000,
      },
      { " * ", "Normal" },
    }

  local ret = {} ---@type snacks.picker.Highlight[][]
  for l, line in ipairs(lines) do
    local new = vim.deepcopy(l == 1 and first or indent)
    extend(new, line)
    ret[l] = new
  end
  return ret
end

---@param comment snacks.gh.Comment
---@param ctx snacks.gh.render.ctx
function M.comment_diff(comment, ctx)
  if not comment.path or not comment.diffHunk then
    return {}
  end
  local count = 1
  local originalLine = comment.originalLine or comment.line or 1
  if comment.originalStartLine then
    count = originalLine - comment.originalStartLine + 1
  end
  count = math.max(ctx.opts.diff.min, math.abs(count))

  local Diff = require("snacks.picker.util.diff")
  local diff = ("diff --git a/%s b/%s\n%s"):format(comment.path, comment.path, comment.diffHunk)
  local ret = Diff.format(diff, {
    max_hunk_lines = count,
    hunk_header = false,
  })
  table.insert(ret, 1, { { "```" } })
  table.insert(ret, { { "```" } })
  return ret
end

---@param comment snacks.gh.Comment
---@param ctx snacks.gh.render.ctx
function M.annotate(comment, ctx)
  if not comment.path or not comment.diffHunk then
    return
  end
  local side = "right"
  for _, thread in ipairs(ctx.item.reviewThreads or {}) do
    for _, c in ipairs(thread.comments or {}) do
      if c.id == comment.id then
        side = (thread.diffSide or "RIGHT"):lower()
        break
      end
    end
  end
  ---@type snacks.diff.Annotation
  local ret = {
    side = side,
    file = comment.path,
    line = comment.line or comment.originalLine or 1,
    text = {},
  }
  ctx.annotations = ctx.annotations or {}
  table.insert(ctx.annotations, ret)
  return ret
end

---@param comment snacks.gh.Comment
---@param ctx snacks.gh.render.ctx
function M.comment(comment, ctx)
  local ret = {} ---@type snacks.picker.Highlight[][]

  local header = {} ---@type snacks.picker.Highlight[]
  extend(header, M.comment_header(comment, {}, ctx))
  ret[#ret + 1] = header

  local annotation ---@type snacks.diff.Annotation?
  if not comment.replyTo then
    annotation = M.annotate(comment, ctx)
    if ctx.diff ~= false then
      -- add diff hunk for top-level comments
      local diff = M.comment_diff(comment, ctx)
      if #diff > 0 then
        vim.list_extend(ret, diff)
        ret[#ret + 1] = {} -- empty line between diff and body
      end
    end
  end

  vim.list_extend(ret, M.comment_body(comment, ctx))
  local replies = M.find_reply(comment.id, ctx)
  for _, reply in ipairs(replies) do
    ret[#ret + 1] = {} -- empty line between comment and reply
    vim.list_extend(ret, M.comment(reply, ctx))
    ctx.comment_skip[reply.id] = true
  end
  if ctx.is_review then
    for _, line in ipairs(ret) do
      local reply_id = comment.replyTo and comment.replyTo.databaseId or comment.databaseId
      if reply_id then
        line[#line + 1] = { "", meta = { comment_id = reply_id } }
      end
    end
  end
  ret = M.indent(ret, ctx)
  if annotation then
    annotation.text = vim.deepcopy(ret)
  end
  return ret
end

---@param id string
---@param ctx snacks.gh.render.ctx
function M.find_reply(id, ctx)
  local ret = {} ---@type snacks.gh.Comment[]
  for _, review in ipairs(ctx.item.reviews or {}) do
    for _, comment in ipairs(review.comments or {}) do
      if comment.replyTo and comment.replyTo.id == id then
        ret[#ret + 1] = comment
      end
    end
  end
  return ret
end

---@param review snacks.gh.Review
---@param ctx snacks.gh.render.ctx
function M.review(review, ctx)
  local ret = {} ---@type snacks.picker.Highlight[][]

  ---@type snacks.gh.Comment[]
  local comments = vim.tbl_filter(function(c)
    return not ctx.comment_skip[c.id]
  end, review.comments or {})

  if #comments == 0 and review.state == "COMMENTED" and ((review.body or ""):match("^%s*$")) then
    return ret
  end

  local header = {} ---@type snacks.picker.Highlight[]
  local state_icon = ctx.opts.icons.review[review.state:lower()] or ctx.opts.icons.pr.open
  extend(header, h.badge(state_icon, "SnacksGhReview" .. util.title(review.state:lower()):gsub(" ", "")))
  header[#header + 1] = { " " }
  local texts = {
    ["CHANGES_REQUESTED"] = "requested changes",
    ["COMMENTED"] = "reviewed",
  }

  local text = texts[review.state] or review.state:lower():gsub("_", " ")
  extend(header, M.comment_header(review, { text = text }, ctx))
  ret[#ret + 1] = header
  vim.list_extend(ret, M.comment_body(review, ctx))
  for _, comment in ipairs(comments) do
    ret[#ret + 1] = {} -- empty line between review and comments
    vim.list_extend(ret, M.comment(comment, ctx))
  end
  return M.indent(ret, ctx)
end

---@param pr snacks.picker.gh.Item
function M.annotations(pr)
  ---@type snacks.gh.render.ctx
  local ctx = {
    item = pr,
    opts = Snacks.gh.config(),
    comment_skip = {},
    is_review = true,
    diff = false,
    markdown = false,
  }
  for _, review in ipairs(pr.reviews or {}) do
    M.review(review, ctx)
  end
  return ctx.annotations
end

return M
