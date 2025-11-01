local Markdown = require("snacks.picker.util.markdown")

local M = {}
local extend = Snacks.picker.highlight.extend

---@param field string
local function time_prop(field)
  return {
    name = Snacks.picker.util.title(field),
    hl = function(item)
      if not item[field] then
        return
      end
      return { { Snacks.picker.util.reltime(item[field]), "SnacksPickerGitDate" } }
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
        local hl = "SnacksGh" .. Snacks.picker.util.title(item.type) .. Snacks.picker.util.title(status)
        local text = icon .. Snacks.picker.util.title(item.status or "other")
        extend(ret, Snacks.picker.highlight.badge(text, { bg = Snacks.util.color(hl), fg = "#ffffff" }))
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
      return Snacks.picker.highlight.badge(opts.icons.user .. " " .. item.author, "SnacksGhUserBadge")
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
          local badge = Snacks.picker.highlight.badge(
            opts.icons.reactions[r.content] .. " " .. tostring(r.count),
            "SnacksGhReactionBadge"
          )
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
        local badge = Snacks.picker.highlight.badge(label.name, "#" .. color)
        vim.list_extend(ret, badge)
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
        local badge = Snacks.picker.highlight.badge(u.login, "Identifier")
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
        return Snacks.picker.highlight.badge(item.item.milestone.title, "Title")
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
      status = Snacks.picker.util.title(status)
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
        local status = check.status == "COMPLETED" and check.conclusion or "pending"
        status = Snacks.picker.util.title(status:lower())
        workflows[check.workflowName .. ":" .. check.name] = status
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
          local badge = Snacks.picker.highlight.badge(icon .. " " .. tostring(count), "SnacksGhCheck" .. status)
          vim.list_extend(ret, badge)
          ret[#ret + 1] = { " " }
        end
      end
      ret[#ret + 1] = { " " }
      for _, status in ipairs(order) do
        local count = stats[status]
        if count then
          ret[#ret + 1] = { string.rep(opts.icons.block, count), "SnacksGHCheck" .. status }
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
        ret = Snacks.picker.highlight.badge(opts.icons.file .. item.changedFiles, "SnacksGhStatBadge")
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

        ret[#ret + 1] = { string.rep(opts.icons.block, additions), "SnacksGHAdditions" }
        ret[#ret + 1] = { string.rep(opts.icons.block, deletions), "SnacksGHDeletions" }
        ret[#ret + 1] = { string.rep(opts.icons.block, neutral), "SnacksGHStat" }
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
  local comments = item.comments or {}

  if #comments > 0 then
    lines[#lines + 1] = {} -- empty line
    lines[#lines + 1] = { { "---", "@punctuation.special.markdown" } }

    for _, comment in ipairs(comments) do
      lines[#lines + 1] = {} -- empty line
      local ch = {} ---@type snacks.picker.Highlight[]
      local is_bot = comment.author.login == "github-actions"
      if is_bot then
        extend(ch, Snacks.picker.highlight.badge(opts.icons.logo .. " " .. comment.author.login, "SnacksGhBotBadge"))
      else
        extend(ch, Snacks.picker.highlight.badge(opts.icons.user .. " " .. comment.author.login, "SnacksGhUserBadge"))
      end
      ch[#ch + 1] = { " on " .. Snacks.picker.util.reltime(comment.created), "SnacksPickerGitDate" }
      local assoc = comment.authorAssociation
      assoc = assoc and assoc ~= "NONE" and Snacks.picker.util.title(assoc:lower()) or nil
      assoc = comment.author.login == item.author and "Author" or assoc
      if assoc then
        ch[#ch + 1] = { " " }
        extend(
          ch,
          Snacks.picker.highlight.badge(
            assoc,
            assoc == "Author" and "SnacksGhAuthorBadge"
              or assoc == "Owner" and "SnacksGhOwnerBadge"
              or "SnacksGhAssocBadge"
          )
        )
      end
      for _, r in ipairs(comment.reactionGroups or {}) do
        ch[#ch + 1] = { " " }
        local badge = Snacks.picker.highlight.badge(
          opts.icons.reactions[r.content:lower()] .. " " .. tostring(r.users.totalCount),
          "SnacksGhReactionBadge"
        )
        extend(ch, badge)
      end
      lines[#lines + 1] = ch

      local body = vim.split(comment.body or "", "\n")
      for _, l in ipairs(body) do
        lines[#lines + 1] = {
          {
            col = 0,
            virt_text = { { "┃", "@punctuation.definition.blockquote.markdown" } },
            virt_text_pos = "overlay",
            virt_text_win_col = 1,
            hl_mode = "combine",
            virt_text_repeat_linebreak = true,
          },
          { "   " },
          { l },
        }
      end
    end
  end

  local buf_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  local changed = #lines ~= #buf_lines
  for l, line in ipairs(lines) do
    local line_text, extmarks = Snacks.picker.highlight.to_text(line)
    if line_text ~= buf_lines[l] then
      vim.api.nvim_buf_set_lines(buf, l - 1, l, false, { line_text })
      changed = true
    end
    for _, extmark in ipairs(extmarks) do
      local e = vim.deepcopy(extmark)
      e.col = nil
      e.row = nil
      e.field = nil
      local ok, err = pcall(vim.api.nvim_buf_set_extmark, buf, ns, l - 1, extmark.col, e)
      if not ok then
        Snacks.notify.error(
          "Failed to set extmark. This should not happen. Please report.\n"
            .. err
            .. "\n```lua\n"
            .. vim.inspect(extmark)
            .. "\n```"
        )
      end
    end
  end
  if #lines < #buf_lines then
    vim.api.nvim_buf_set_lines(buf, #lines, -1, false, {})
  end

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

  vim.bo[buf].modified = false
  vim.bo[buf].modifiable = false
end

return M
