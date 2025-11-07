local Async = require("snacks.picker.util.async")
local Item = require("snacks.gh.item")
local Proc = require("snacks.util.spawn")

---@class snacks.gh.api
local M = {}

---@type table<string, snacks.picker.gh.Item>
local cache = setmetatable({}, { __mode = "v" })
local pr_cache = {} ---@type table<string, snacks.picker.gh.Item>

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
      "headRefOid",
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
  opts = opts or {}
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
            if opts.notify ~= false then
              Snacks.debug.cmd({
                header = "GH Error",
                cmd = { "gh", unpack(args) },
                footer = proc:err(),
                level = vim.log.levels.ERROR,
                props = { input = opts.input },
              })
            end
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
    notify = opts.notify,
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
    input = opts.input and vim.json.encode(opts.input) or nil,
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
---@param item snacks.gh.api.View|{number?: number}
---@param opts? { fields?: string[], force?: boolean }
function M.view(cb, item, opts)
  opts = opts or {}
  local api_opts = get_opts(item.type, "view")
  if opts.fields then
    api_opts.fields = vim.list_extend(api_opts.fields, opts.fields)
  end

  item = M.get_cached(item)
  local todo = Item.is(item) and item:need(api_opts.fields) or api_opts.fields
  if opts.force or item.dirty then
    todo = api_opts.fields
  end

  if #todo == 0 then
    cb(item, false)
    return
  end

  local args = { item.type, "view", tostring(item.number) }
  local need_reviews = item.type == "pr" and vim.tbl_contains(todo, "comments")
  local it ---@type snacks.gh.Item?
  local completed = 0
  local fetch_comments = false
  local procs = {} ---@type snacks.spawn.Proc[]

  ---@param data? snacks.gh.Item|{}
  local function handler(data)
    it = data and vim.tbl_extend("force", it or {}, data or {}) or it
    if fetch_comments then
      fetch_comments = false
      item.repo = it and Item.get_repo(it.url) or nil
      procs[#procs + 1] = M.comments(item, handler)
    end
    completed = completed + 1
    if completed < #procs then
      return
    end
    if not it then
      return cb()
    end
    item = Item.new(item, api_opts)
    item:update(it, todo)
    item.dirty = false
    cb(cache_set(item), true)
  end

  if need_reviews then
    todo = vim.tbl_filter(function(f)
      return f ~= "comments" and f ~= "reviews"
    end, todo)
    if item.repo then
      procs[#procs + 1] = M.comments(item, handler)
    else
      -- fetch comments once we fetched the item
      fetch_comments = true
    end
  end

  if #todo > 0 then
    ---@param data? snacks.gh.Item
    procs[#procs + 1] = M.fetch(function(_, data)
      handler(data)
    end, {
      args = args,
      fields = todo,
      repo = item.repo or api_opts.repo,
    })
  end

  ---@type snacks.picker.Waitable
  return {
    ---@async
    wait = function()
      for _, proc in ipairs(procs) do
        proc:wait()
      end
    end,
  }
end

---@param item snacks.gh.api.View
---@param opts? { fields?: string[], force?: boolean }
---@async
function M.get(item, opts)
  local ret ---@type snacks.picker.gh.Item?
  local procs = M.view(function(it)
    ret = it
  end, item, opts)
  if procs then
    procs:wait()
  end
  return ret
end

---@param item snacks.gh.api.View
function M.get_cached(item)
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
    -- comment
    params = {
      owner = owner,
      name = name,
      number = item.number,
    },

    -- inject: graphql
    query = [[
      query($owner: String!, $name: String!, $number: Int!) {
        repository(owner: $owner, name: $name) {
          pullRequest(number: $number) {
            reviewThreads(first: 100) {
              nodes {
                id
                diffSide
                comments(first: 50) {
                  nodes {
                    id
                  }
                }
              }
            }
            reviews(first: 100) {
              nodes {
                id
                databaseId
                author { login }
                authorAssociation
                body
                state
                commit { oid }
                submittedAt
                createdAt
                viewerDidAuthor
                reactionGroups {
                  content
                  users { totalCount }
                }
                comments(first: 50) {
                  nodes {
                    id
                    databaseId
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
                    replyTo { id databaseId }
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
                databaseId
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

---@async
function M.current_pr()
  local root = Snacks.git.get_root(vim.uv.cwd() or ".")
  if not root then
    return
  end
  ---@type snacks.picker.gh.Item?
  local pr
  local branch = Proc.exec({ "git", "branch", "--show-current" })

  local key = root .. "::" .. branch
  if pr_cache[key] then
    return pr_cache[key]
  end

  -- try with `pr view` first
  local api_opts = get_opts("pr", "list")
  pr = M.fetch_sync({
    args = { "pr", "view" },
    fields = api_opts.fields,
    notify = false,
  })
  pr = pr and cache_set(Item.new(pr, api_opts)) or nil
  if pr then
    pr_cache[key] = pr
    return pr
  end

  -- assume this is the main branch of a fork
  local author, main = branch:match("^(.-)/(.+)$")
  if not author or not main then
    return
  end
  local repo = M.cmd_sync({
    args = { "repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner" },
    notify = false,
  })
  if not repo then
    return
  end
  repo = vim.trim(repo)

  M.list("pr", function(items)
    pr_cache[key] = items and items[1] or nil
    pr = pr_cache[key]
  end, {
    author = author,
    head = main,
    base = main,
    repo = repo,
    limit = 1,
    notify = false,
  }):wait()
  return pr
end

return M
