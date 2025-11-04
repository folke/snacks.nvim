local Async = require("snacks.picker.util.async")
local Host = require("snacks.gh.host")
local Item = require("snacks.gh.item")

---@class snacks.gh.api
local M = {}

---@type table<string, snacks.picker.gh.Item>
local cache = setmetatable({}, { __mode = "v" })
local pr_cache = {} ---@type table<string, snacks.picker.gh.Item>

-- Convenience aliases for the Host module
local get_host = Host.get
local escape_pattern = Host.escape_pattern

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
      "reviews",
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

---@generic T
---@param fn fun(cb:fun(proc:snacks.spawn.Proc, data?:any), opts:T): snacks.spawn.Proc
---@return fun(opts:T): any?
local function wrap_sync(fn)
  ---@async
  return function(opts)
    local ret ---@type any
    fn(function(_, data)
      ret = data
    end, opts):wait()
    return ret
  end
end

--- Cleanup GraphQL internal nodes and reaction groups
---@param ret table<string, any>
local function clean_graphql(ret)
  for k, v in pairs(ret) do
    if type(v) == "table" then
      clean_graphql(v)
    end
    if k == "reactionGroups" and type(v) == "table" then
      ---@param r snacks.gh.Reaction
      ret[k] = vim.tbl_filter(function(r)
        return r.users and r.users.totalCount and r.users.totalCount > 0
      end, v)
      ret[k] = #ret[k] > 0 and ret[k] or nil
    elseif type(v) == "table" and type(v.nodes) == "table" and vim.tbl_count(v) == 1 then
      ret[k] = v.nodes
    elseif v == vim.NIL then
      ret[k] = nil
    end
  end
  return ret
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

  -- Setup spawn options
  local spawn_opts = {
    cmd = "gh",
    args = args,
    input = opts.input,
    timeout = 10000,
    -- debug = true,
  }

  -- Setup environment variables for custom GitHub hosts
  -- NOTE: get_host() uses os.getenv (safe everywhere) and Host.get() caches the value
  -- to avoid repeated git calls, even when called from spawn callbacks.
  -- Only set env when using a custom host - otherwise inherit parent's environment
  local host = get_host()
  if host ~= "github.com" then
    -- Get full environment and add GH_HOST
    -- Safe to use vim.uv.os_environ() here since M.cmd is called from main execution,
    -- not from fast event contexts. The spawned process callbacks will use the cached host.
    local uv = vim.uv or vim.loop
    local env_table = uv.os_environ() or {}
    env_table.GH_HOST = host

    -- Convert to array format required by uv.spawn: ["KEY=value", ...]
    -- This format is required by libuv's spawn function
    local env = {}
    for k, v in pairs(env_table) do
      table.insert(env, k .. "=" .. v)
    end
    spawn_opts.env = env
  end

  spawn_opts.on_exit = function(proc, err)
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
  end

  ret = Spawn.new(spawn_opts)
  return ret
end
M.cmd_sync = wrap_sync(M.cmd)

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
M.fetch_sync = wrap_sync(M.fetch)

---@param cb fun(proc: snacks.spawn.Proc, data?: table)
---@param opts snacks.gh.api.Api
function M.request(cb, opts)
  local args = { "api", opts.endpoint }
  set_options(args, config.api.options or {}, opts)
  if opts.input then
    vim.list_extend(args, { "--input", "-" })
  end
  for k, v in pairs(opts.fields or {}) do
    vim.list_extend(args, { "--raw-field", ("%s=%s"):format(k, tostring(v)) })
  end
  for k, v in pairs(opts.params or {}) do
    vim.list_extend(args, { "--field", ("%s=%s"):format(k, tostring(v)) })
  end
  for k, v in pairs(opts.header or {}) do
    vim.list_extend(args, { "--header", ("%s:%s"):format(k, tostring(v)) })
  end
  return M.cmd(function(proc, data)
    cb(proc, data and data:find("%S") and proc:json() or nil)
  end, {
    args = args,
    input = opts.input,
    on_error = opts.on_error,
  })
end
M.request_sync = wrap_sync(M.request)

---@param cb fun(proc: snacks.spawn.Proc, data?: table)
---@param opts snacks.gh.api.GraphQL
function M.graphql(cb, opts)
  opts = Snacks.config.merge(vim.deepcopy(opts), {
    endpoint = "graphql",
    fields = {
      query = opts.query,
    },
  })
  return M.request(function(proc, data)
    if not data then
      return
    end
    if data.errors then
      local msgs = {} ---@type string[]
      for _, err in ipairs(data.errors) do
        msgs[#msgs + 1] = err.message
      end
      vim.schedule(function()
        Snacks.debug.cmd({
          header = "GH GraphQL Error",
          cmd = { "gh", "api", "graphql" },
          footer = table.concat(msgs, "\n"),
          level = vim.log.levels.ERROR,
        })
        if opts.on_error then
          opts.on_error(proc, table.concat(msgs, "\n"))
        end
      end)
      return
    end
    cb(proc, clean_graphql(data.data))
  end, opts)
end
M.graphql_sync = wrap_sync(M.graphql)

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

---@param cb fun(item?: snacks.picker.gh.Item, updated?: boolean)
---@param item snacks.gh.api.View
---@param opts? { fields?: string[], force?: boolean }
function M.view(cb, item, opts)
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
  local need_reviews = item.type == "pr" and vim.tbl_contains(todo, "comments")
  local it ---@type snacks.gh.Item?
  local pending = need_reviews and 2 or 1

  ---@param data? snacks.gh.Item|{}
  local function handler(data)
    it = data and vim.tbl_extend("force", it or {}, data or {}) or it
    pending = pending - 1
    if pending > 0 then
      return
    end
    if not it then
      return cb()
    end
    item = Item.new(item, api_opts)
    item:update(it, todo)
    cb(cache_set(item), true)
  end

  if need_reviews then
    todo = vim.tbl_filter(function(f)
      return f ~= "comments" and f ~= "reviews"
    end, todo)
    M.comments(item, handler)
  end

  ---@param data? snacks.gh.Item
  return M.fetch(function(_, data)
    handler(data)
  end, {
    args = args,
    fields = todo,
    repo = item.repo or api_opts.repo,
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

---@param cb fun(data?: {comments: snacks.gh.Comment[], reviews: snacks.gh.Review[]})
---@param item snacks.gh.api.View
function M.comments(item, cb)
  local owner, name = item.repo:match("^(.-)/(.-)$")
  return M.graphql(function(_, data)
    if not data then
      return cb()
    end
    cb(data.repository.pullRequest)
  end, {
    params = {
      owner = owner,
      name = name,
      number = item.number,
    },
    query = [[
      query($owner: String!, $name: String!, $number: Int!) {
        repository(owner: $owner, name: $name) {
          pullRequest(number: $number) {
            reviews(first: 100) {
              nodes {
                id
                author { login }
                authorAssociation
                body
                state
                commit { oid }
                submittedAt
                reactionGroups {
                  content
                  users { totalCount }
                }
                comments(first: 50) {
                  nodes {
                    id
                    body
                    path
                    diffHunk
                    line
                    startLine
                    originalLine
                    originalStartLine
                    createdAt
                    subjectType
                    author { login }
                    replyTo { id }
                    reactionGroups {
                      content
                      users { totalCount }
                    }
                  }
                }
              }
            }
            comments(first: 100) {
              nodes {
                id
                body
                author { login }
                authorAssociation
                createdAt
                reactionGroups {
                  content
                  users { totalCount }
                }
              }
            }
          }
        }
      }
    ]],
  })
end

function M.get_branch()
  local branch = vim.fn.system({ "git", "branch", "--show-current" }):gsub("\n", "")

  -- Get all config in one call
  local git_config = vim.fn
    .system({
      "git",
      "config",
      "--get-regexp",
      ("^(branch\\.%s\\.|remote\\.)"):format(branch),
    })
    :gsub("\n$", "")

  local cfg = {} ---@type table<string, string>
  for _, line in ipairs(vim.split(git_config, "\n")) do
    local key, value = line:match("^([^%s]+)%s+(.+)$")
    if key then
      cfg[key] = value
    end
  end

  -- Extract values
  local remote = cfg[("branch.%s.remote"):format(branch)] or ""
  local merge = cfg[("branch.%s.merge"):format(branch)] or ""
  local origin_url = cfg["remote.origin.url"] or ""

  -- Get fork URL (either named remote or direct URL)
  local url = (remote:match("^https://") or remote:match("^git@")) and remote
    or cfg[("remote.%s.url"):format(remote)]
    or remote

  -- Parse author from fork URL
  local author ---@type string?
  if url ~= "" then
    ---@type string?
    local host_pattern = escape_pattern(get_host())
    local owner_repo = url:match(host_pattern .. "[:/](.+/.+)%.git") or url:match(host_pattern .. "[:/](.+/.+)$")
    author = owner_repo and owner_repo:match("^([^/]+)/") or nil
  end

  -- Parse repo from origin
  local host_pattern = escape_pattern(get_host())
  local repo = origin_url:match(host_pattern .. "[:/](.+/.+)%.git") or origin_url:match(host_pattern .. "[:/](.+/.+)$")

  -- Fallback: try without host restriction for non-standard URLs
  if not repo then
    repo = origin_url:match("[:/](.+/.+)%.git") or origin_url:match("[:/](.+/.+)$")
  end

  -- Parse head from merge ref
  local head = merge:match("^refs/heads/(.+)$") or branch

  -- Get base branch (default branch from origin)
  local base = vim.fn.system({ "git", "symbolic-ref", "refs/remotes/origin/HEAD" }):gsub("\n", "")
  base = base:match("refs/remotes/origin/(.+)") or "main"

  ---@type snacks.gh.api.Branch
  return {
    url = url,
    author = author,
    repo = repo,
    branch = branch,
    head = head,
    base = base,
  }
end

---@param cb fun(item?: snacks.picker.gh.Item)
function M.current_pr(cb)
  local branch = M.get_branch()
  local key = string.format("%s:%s/%s->%s", branch.author or "", branch.repo or "", branch.head, branch.base)
  if pr_cache[key] then
    return cb(pr_cache[key])
  end
  return M.list("pr", function(items)
    pr_cache[key] = items and items[1] or nil
    cb(pr_cache[key])
  end, {
    author = branch.author,
    head = branch.head,
    base = branch.base,
    repo = branch.repo,
    limit = 1,
  })
end

return M
