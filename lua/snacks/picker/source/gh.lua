local Api = require("snacks.gh.api")
local Actions = require("snacks.gh.actions").actions

local M = {}

M.actions = setmetatable({}, {
  __index = function(t, k)
    if type(k) ~= "string" then
      return
    end
    if not Actions[k] then
      return nil
    end
    ---@type snacks.picker.Action
    local action = {
      desc = Actions[k].desc,
      action = function(picker, item, action)
        ---@diagnostic disable-next-line: param-type-mismatch
        return Actions[k].action(item, {
          picker = picker,
          items = picker:selected({ fallback = true }),
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

---@param opts snacks.picker.Config
---@type snacks.picker.finder
function M.issue(opts, ctx)
  return M.gh(
    vim.tbl_extend("force", {
      type = "issue",
    }, opts),
    ctx
  )
end

---@param opts snacks.picker.Config
---@type snacks.picker.finder
function M.pr(opts, ctx)
  return M.gh(
    vim.tbl_extend("force", {
      type = "pr",
    }, opts),
    ctx
  )
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
  return require("snacks.picker.source.diff").diff(
    ctx:opts({
      cmd = "gh",
      args = args,
      cwd = cwd,
    }),
    ctx
  )
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
    local item = Api.get(opts)
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
