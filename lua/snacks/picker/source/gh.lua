local Actions = require("snacks.gh.actions")
local Api = require("snacks.gh.api")

local M = {}

M.actions = setmetatable({}, {
  __index = function(t, k)
    if type(k) ~= "string" then
      return
    end
    if not Actions.actions[k] then
      return nil
    end
    ---@type snacks.picker.Action
    local action = {
      desc = Actions.actions[k].desc,
      action = function(picker, item, action)
        local items = picker:selected({ fallback = true })
        if item.gh_item then
          item = item.gh_item
          items = { item }
        end
        ---@diagnostic disable-next-line: param-type-mismatch
        return Actions.actions[k].action(item, {
          picker = picker,
          items = items,
          action = action,
        })
      end,
    }
    rawset(t, k, action)
    return action
  end,
})

---@param opts snacks.picker.gh.list.Config
---@type snacks.picker.finder
function M.gh(opts, ctx)
  if ctx.filter.search ~= "" then
    opts.search = ctx.filter.search
  end
  ---@async
  return function(cb)
    Api.list(opts.type, function(items)
      for _, item in ipairs(items) do
        cb(item)
      end
    end, opts):wait()
  end
end

---@param opts snacks.picker.gh.issue.Config
---@type snacks.picker.finder
function M.issue(opts, ctx)
  return M.gh(
    vim.tbl_extend("force", {
      type = "issue",
    }, opts),
    ctx
  )
end

---@param opts snacks.picker.gh.pr.Config
---@type snacks.picker.finder
function M.pr(opts, ctx)
  return M.gh(
    vim.tbl_extend("force", {
      type = "pr",
    }, opts),
    ctx
  )
end

---@param opts snacks.picker.gh.actions.Config
---@type snacks.picker.finder
function M.get_actions(opts, ctx)
  opts = opts or {}
  ---@async
  return function(cb)
    local item = opts.item
    if not opts.item and not opts.number then
      item = Api.current_pr()
    end

    if not item then
      local required = { "type", "repo", "number" }
      local missing = vim.tbl_filter(function(field)
        return opts[field] == nil
      end, required) ---@type string[]
      if #missing > 0 then
        Snacks.notify.error({
          "Missing required options for `Snacks.picker.gh_actions()`:",
          "- `" .. table.concat(missing, ", ") .. "`",
          "",
          "Either provide the fields, or run in a git repo with a **current PR**.",
        }, { title = "Snacks Picker GH Actions" })
        return
      end
      item = Api.get({ type = opts.type or "pr", repo = opts.repo, number = opts.number })
      if not item then
        Snacks.notify.error("snacks.picker.gh.get_actions: Failed to get item")
        return
      end
    end

    local actions = ctx.async:schedule(function()
      return Actions.get_actions(item, {
        picker = ctx.picker,
        items = { item },
      })
    end)
    actions.gh_actions = nil -- remove this action
    actions.gh_perform_action = nil -- remove this action
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
    for i, it in ipairs(items) do
      it.text = ("%d. %s"):format(i, it.text)
      cb(it)
    end
  end
end

---@param opts snacks.picker.gh.diff.Config
---@type snacks.picker.finder
function M.diff(opts, ctx)
  opts = opts or {}
  if not opts.pr then
    Snacks.notify.error("snacks.picker.gh.diff: `opts.pr` is required")
    return {}
  end
  local cwd = ctx:git_root()
  local args = { "pr", "diff", tostring(opts.pr) }
  if opts.repo then
    vim.list_extend(args, { "--repo", opts.repo })
  end

  opts.previewers.diff.style = "fancy" -- only fancy style support inline review comments

  local Render = require("snacks.gh.render")
  local Diff = require("snacks.picker.source.diff")
  ---@async
  return function(cb)
    local item = Api.get({ type = "pr", repo = opts.repo, number = opts.pr })

    -- fetch on the main thread since rendering uses non-fast APIs
    local annotations = ctx.async:schedule(function()
      return Render.annotations(item)
    end)

    Diff.diff(
      ctx:opts({
        cmd = "gh",
        args = args,
        cwd = cwd,
        annotations = annotations,
      }),
      ctx
    )(function(it)
      it.gh_item = item
      cb(it)
    end)
  end
end

---@param opts snacks.picker.gh.reactions.Config
---@type snacks.picker.finder
function M.reactions(opts, ctx)
  if not opts.repo then
    Snacks.notify.error("snacks.picker.gh.reactions: `opts.repo` is required")
    return {}
  end
  if not opts.number then
    Snacks.notify.error("snacks.picker.gh.reactions: `opts.number` is required")
    return {}
  end

  local all = { "+1", "-1", "laugh", "hooray", "confused", "heart", "rocket", "eyes" }
  ---@async
  return function(cb)
    local items = {} ---@type table<string, snacks.picker.finder.Item>
    local user = Api.user()

    ---@type {user:snacks.gh.User, content:string}[]
    local reactions = Api.request_sync({
      endpoint = ("/repos/%s/issues/%s/reactions"):format(opts.repo, opts.number),
    })

    for _, r in ipairs(reactions) do
      if r.user.login == user.login then
        items[r.content] = setmetatable({
          text = r.content,
          reaction = r.content,
          added = true,
        }, { __index = r })
      end
    end

    for _, reaction in ipairs(all) do
      cb(items[reaction] or {
        text = reaction,
        reaction = reaction,
        added = false,
      })
    end
  end
end

---@param opts snacks.picker.gh.labels.Config
---@type snacks.picker.finder
function M.labels(opts, ctx)
  if not opts.repo then
    Snacks.notify.error("snacks.picker.gh.labels: `opts.repo` is required")
    return {}
  end
  if not opts.number then
    Snacks.notify.error("snacks.picker.gh.labels: `opts.number` is required")
    return {}
  end

  ---@async
  return function(cb)
    ---@type {labels: snacks.gh.Label[]}
    local repo = Api.fetch_sync({
      fields = { "labels" },
      args = { "repo", "view", opts.repo },
    })
    local item = Api.get_cached(opts)
    assert(item, "Failed to get item for labels")
    local added = {} ---@type table<string, boolean>
    for _, label in ipairs(item.labels or {}) do
      added[label.name] = true
    end
    repo.labels = repo.labels or {}
    table.sort(repo.labels, function(a, b)
      if added[a.name] ~= added[b.name] then
        return added[a.name] == true
      end
      return a.name:lower() < b.name:lower()
    end)

    for _, r in ipairs(repo.labels or {}) do
      cb({
        text = r.name,
        label = r.name,
        added = added[r.name] == true,
        item = r,
      })
    end
  end
end

---@param item snacks.picker.gh.Item
---@type snacks.picker.format
function M.format(item, picker)
  local ret = {} ---@type snacks.picker.Highlight[]
  local a = Snacks.picker.util.align

  local config = require("snacks.gh").config()
  -- Status Icon
  local icons = config.icons[item.type]
  local status = icons[item.status] and item.status or "other"
  if status then
    local icon = icons[status]
    local icon_hl = "SnacksGh" .. Snacks.picker.util.title(item.type) .. Snacks.picker.util.title(status)
    ret[#ret + 1] = { a(icon, 2), icon_hl }
    ret[#ret + 1] = { " " }
  end

  -- Number / Hash
  if item.hash then
    ret[#ret + 1] = { a(item.hash, 8), "SnacksPickerDimmed" }
  end

  -- Updated At
  -- if item.updated then
  --   ret[#ret + 1] = { a(Snacks.picker.util.reltime(item.updated), 12), "SnacksPickerGitDate" }
  -- end

  -- Title
  if item.title then
    item.msg = item.title
    Snacks.picker.highlight.extend(ret, Snacks.picker.format.commit_message(item, picker))
  end

  -- Author
  if item.author and not item.item.author.is_bot then
    ret[#ret + 1] = { " ", nil }
    ret[#ret + 1] = { "@" .. item.author, "SnacksPickerGitAuthor" }
  end

  -- Labels
  for _, label in ipairs(item.item.labels or {}) do
    ret[#ret + 1] = { " ", nil }
    local color = label.color or "888888"
    local badge = Snacks.picker.highlight.badge(label.name, "#" .. color)
    vim.list_extend(ret, badge)
  end

  return ret
end

---@param ctx snacks.picker.preview.ctx
function M.preview_diff(ctx)
  Snacks.picker.preview.diff(ctx)
  local item = ctx.item.gh_item ---@type snacks.picker.gh.Item?
  if item then
    vim.b[ctx.buf].snacks_gh = {
      repo = item.repo,
      type = item.type,
      number = item.number,
    }
  end
end

---@param ctx snacks.picker.preview.ctx
function M.preview(ctx)
  local config = require("snacks.gh").config()
  local item = ctx.item
  item.wo = config.wo
  item.bo = config.bo
  item.preview_title = ("%s %s %s"):format(
    config.icons.logo,
    (item.type == "issue" and "Issue" or "PR"),
    (item.hash or "")
  )
  return Snacks.picker.preview.file(ctx)
end

---@type snacks.picker.format
function M.format_label(item, picker)
  local ret = {} ---@type snacks.picker.Highlight[]
  local added = item.added
  if picker.list:is_selected(item) then
    added = not added -- reflect the change that will happen on action
  end
  ret[#ret + 1] = { added and "󰱒 " or "󰄱 ", "SnacksPickerDelim" }
  ret[#ret + 1] = { " " }
  local color = item.item.color or "888888"
  local badge = Snacks.picker.highlight.badge(item.label, "#" .. color)
  vim.list_extend(ret, badge)
  return ret
end

---@param item snacks.picker.gh.Action
---@type snacks.picker.format
function M.format_action(item, picker)
  local ret = {} ---@type snacks.picker.Highlight[]

  if item.action.icon then
    ret[#ret + 1] = { item.action.icon, "Special" }
    ret[#ret + 1] = { " " }
  end

  local count = picker:count()
  local idx = tostring(item.idx)
  idx = (" "):rep(#tostring(count) - #idx) .. idx
  ret[#ret + 1] = { idx .. ".", "SnacksPickerIdx" }

  ret[#ret + 1] = { " " }

  if item.desc then
    ret[#ret + 1] = { item.desc or item.name }
    Snacks.picker.highlight.highlight(ret, {
      ["#%d+"] = "Number",
    })
  end
  return ret
end

---@type snacks.picker.format
function M.format_reaction(item, picker)
  local config = require("snacks.gh").config()
  local ret = {} ---@type snacks.picker.Highlight[]
  local name = item.reaction
  name = name == "+1" and "thumbs_up" or name == "-1" and "thumbs_down" or name
  local added = item.added
  if picker.list:is_selected(item) then
    added = not added -- reflect the change that will happen on action
  end
  ret[#ret + 1] = { added and "󰱒 " or "󰄱 ", "SnacksPickerDelim" }
  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { config.icons.reactions[name] or name }
  return ret
end

return M
