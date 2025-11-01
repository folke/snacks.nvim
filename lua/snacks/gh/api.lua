local Async = require("snacks.picker.util.async")
local Item = require("snacks.gh.item")

---@class snacks.gh.api
local M = {}

---@type table<string, snacks.picker.gh.Item>
local cache = setmetatable({}, { __mode = "v" })

---@type table<string, snacks.gh.api.Config|{}>
local config = {
  base = {
    list = {
      "author",
      "closedAt",
      "createdAt",
      "id",
      "body",
      "labels",
      "number",
      "reactionGroups",
      "state",
      "title",
      "updatedAt",
      "url",
    },
    view = { "comments" },
    text = { "author", "hash", "label", "title" },
    options = { "app", "assignee", "author", "jq", "label", "repo", "search", "state" },
  },
  api = {
    options = { "cache", "jq", "method", "paginate", "silent", "slurp" },
  },
  issue = {
    list = { "stateReason" },
    options = { "mention", "milestone" },
    ---@param item snacks.picker.gh.Item
    transform = function(item)
      item.status = item.state == "closed" and item.state_reason or item.state
      return item
    end,
  },
  pr = {
    options = { "base", "draft" },
    list = {
      "mergedAt",
      "changedFiles",
      "mergeable",
      "mergeStateStatus",
      "isDraft",
    },
    view = {
      "additions",
      "baseRefName",
      "deletions",
      "headRefName",
      "mergedAt",
      "statusCheckRollup",
    },
    ---@param item snacks.picker.gh.Item
    transform = function(item)
      item.status = item.draft and "draft" or item.state
      return item
    end,
  },
}

---@param item snacks.gh.api.View
local function cache_get(item)
  return cache[Item.to_uri(item)]
end

---@param item snacks.picker.gh.Item
local function cache_set(item)
  cache[item.uri] = item
  return item
end

---@param what "issue" | "pr"
---@param key "list" | "view"
local function get_opts(what, key)
  local base = vim.deepcopy(config.base)
  local specific = vim.deepcopy(config[what] or {})
  base.type = what
  base.fields = vim.list_extend(base.list or {}, specific.list or {})
  if key ~= "list" then
    base.fields = vim.list_extend(base.fields, base[key] or {})
    base.fields = vim.list_extend(base.fields, specific[key] or {})
  end
  base.text = vim.list_extend(base.text, specific.text or {})
  base.options = vim.list_extend(base.options, specific.options or {})
  base.transform = specific.transform
  return base
end

---@param args string[]
---@param options string[]
---@param opts table<string, string|boolean|nil>
local function set_options(args, options, opts)
  for _, option in ipairs(options or {}) do
    local value = opts[option] ---@type string|boolean|nil
    if type(value) == "boolean" and value then
      args[#args + 1] = "--" .. option
    elseif value and value ~= "" then
      vim.list_extend(args, { "--" .. option, tostring(value) })
    end
  end
end

---@param cb fun(proc: snacks.spawn.Proc, data?: string)
---@param opts snacks.gh.api.Cmd
function M.cmd(cb, opts)
  local args = vim.deepcopy(opts.args)
  if opts.repo then
    vim.list_extend(args, { "--repo", opts.repo })
  end
  local Spawn = require("snacks.util.spawn")
  local async = Async.running()
  local ret ---@type snacks.spawn.Proc

  if async then
    async:on("abort", function()
      if ret and ret:running() then
        ret:kill()
      end
    end)
  end
  ret = Spawn.new({
    cmd = "gh",
    args = args,
    input = opts.input,
    timeout = 10000,
    -- debug = true,
    on_exit = function(proc, err)
      if err then
        vim.schedule(function()
          if not proc.aborted then
            Snacks.debug.cmd({
              header = "GH Error",
              cmd = { "gh", unpack(args) },
              footer = proc:err(),
              level = vim.log.levels.ERROR,
            })
            if opts.on_error then
              opts.on_error(proc, proc:err())
            end
          end
        end)
        return
      end
      return cb(proc, not err and proc:out() or nil)
    end,
  })
  return ret
end

---@param opts snacks.gh.api.Cmd
---@async
function M.cmd_sync(opts)
  local ret ---@type any
  M.cmd(function(_, data)
    ret = data
  end, opts):wait()
  return ret
end

---@param cb fun(proc: snacks.spawn.Proc, data?: unknown)
---@param opts snacks.gh.api.Fetch
function M.fetch(cb, opts)
  local args = vim.deepcopy(opts.args)
  vim.list_extend(args, { "--json", table.concat(opts.fields, ",") })
  return M.cmd(function(proc, data)
    cb(proc, data and proc:json() or nil)
  end, {
    args = args,
    repo = opts.repo,
  })
end

---@param opts snacks.gh.api.Fetch
---@async
function M.fetch_sync(opts)
  local ret ---@type any
  M.fetch(function(_, data)
    ret = data
  end, opts):wait()
  return ret
end

---@param cb fun(proc: snacks.spawn.Proc, data?: table)
---@param opts snacks.gh.api.Api
function M.request(cb, opts)
  local args = { "api", opts.endpoint }
  set_options(args, config.api.options or {}, opts)
  if opts.input then
    args[#args + 1] = "--input"
    args[#args + 1] = "-"
  end
  for k, v in pairs(opts.fields or {}) do
    args[#args + 1] = "--raw-field"
    args[#args + 1] = string.format("%s=%s", k, tostring(v))
  end
  for k, v in pairs(opts.header or {}) do
    args[#args + 1] = "--header"
    args[#args + 1] = string.format("%s: %s", k, tostring(v))
  end
  return M.cmd(function(proc, data)
    cb(proc, data and data:find("%S") and proc:json() or nil)
  end, {
    args = args,
    input = opts.input,
    on_error = opts.on_error,
  })
end

---@param opts snacks.gh.api.Api
---@async
function M.request_sync(opts)
  local ret ---@type any
  M.request(function(_, data)
    ret = data
  end, opts):wait()
  return ret
end

---@async
function M.user()
  ---@type snacks.gh.User
  return M.request_sync({
    endpoint = "/user",
  })
end

---@param what "issue" | "pr"
---@param cb fun(items?: snacks.picker.gh.Item[])
---@param opts? snacks.picker.gh.Config
function M.list(what, cb, opts)
  opts = opts or {}
  local api_opts = get_opts(what, "list")
  local args = { what, "list" }

  vim.list_extend(args, { "--limit", tostring(opts.limit or 50) })
  set_options(args, api_opts.options, opts)

  ---@param data? snacks.gh.Item[]
  return M.fetch(function(_, data)
    if not data then
      return cb()
    end
    ---@param item snacks.gh.Item
    return cb(vim.tbl_map(function(item)
      return cache_set(Item.new(item, api_opts))
    end, data))
  end, {
    args = args,
    fields = api_opts.fields,
    repo = opts.repo,
  })
end

---@param item snacks.gh.api.View
---@param cb fun(item?: snacks.picker.gh.Item, updated?: boolean)
---@param opts? { fields?: string[], force?: boolean }
function M.view(item, cb, opts)
  opts = opts or {}
  local api_opts = get_opts(item.type, "view")
  if opts.fields then
    api_opts.fields = vim.list_extend(api_opts.fields, opts.fields)
  end

  item = not Item.is(item) and cache_get(item) or item
  local todo = Item.is(item) and item:need(api_opts.fields) or api_opts.fields
  if opts.force or item.dirty then
    todo = api_opts.fields
    item.dirty = false
  end

  if #todo == 0 then
    cb(item, false)
    return
  end

  local args = { item.type, "view", tostring(item.number) }
  ---@param data? snacks.gh.Item
  return M.fetch(function(_, data)
    if not data then
      return cb()
    end
    item = Item.new(item, api_opts)
    item:update(data, todo)
    cb(cache_set(item), true)
  end, {
    args = args,
    fields = todo,
    repo = api_opts.repo,
  })
end

---@param item snacks.gh.api.View
function M.get(item)
  return not Item.is(item) and cache_get(item) or item
end

---@param item snacks.picker.gh.Item
function M.refresh(item)
  item.dirty = true
  cache_set(item)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      if vim.api.nvim_buf_get_name(buf) == item.uri then
        require("snacks.gh.buf").attach(buf, item)
      end
    end
  end
end

return M
