---@diagnostic disable: missing-fields
local M = {}

---@class snacks.explorer.git.Status
---@field status string
---@field file string

local uv = vim.uv or vim.loop

local CACHE_TTL = 15 * 60 -- 15 minutes

M.state = {} ---@type table<string, {tick: number, last: number}>

---@param path string
function M.refresh(path)
  for root in pairs(M.state) do
    if path == root or path:find(root .. "/", 1, true) == 1 then
      M.state[root].last = 0
    end
  end
end

---@param cwd string
function M.is_dirty(cwd)
  local root = Snacks.git.get_root(cwd)
  if not root then
    return false
  end
  return M.state[root] == nil or M.state[root].last == 0
end

---@param cwd string
---@param opts? {on_update?: fun(), ttl?: number, force?: boolean, untracked?: boolean}
function M.update(cwd, opts)
  opts = opts or {}
  local ttl = opts.ttl or CACHE_TTL
  if opts.force then
    ttl = 0
  end
  local root = Snacks.git.get_root(cwd)

  if not root then
    return M._update(cwd, {})
  end
  local now = os.time()
  M.state[root] = M.state[root] or { tick = 0, last = 0 }
  local state = M.state[root]
  if now - state.last < ttl then
    return
  end
  state.last = now
  state.tick = state.tick + 1
  local tick = state.tick

  local output = ""
  local stdout = assert(uv.new_pipe())
  local handle ---@type uv.uv_process_t
  handle = uv.spawn("git", {
    stdio = { nil, stdout, nil },
    cwd = root,
    hide = true,
    args = {
      "--no-pager",
      "status",
      "--porcelain=v1",
      "--ignored=matching",
      "-z",
      opts.untracked and "-unormal" or "-uno",
    },
  }, function()
    handle:close()
  end)

  if not handle then
    return M._update(cwd, {})
  end

  local function process()
    if not M.state[root] or M.state[root].tick ~= tick then
      return
    end
    local ret = {} ---@type snacks.explorer.git.Status[]
    for _, line in ipairs(vim.split(output, "\0")) do
      if line ~= "" then
        local status, file = line:match("^(..) (.+)$")
        if status then
          ret[#ret + 1] = {
            status = status,
            file = root .. "/" .. file,
          }
        end
      end
    end
    if M._update(cwd, ret) and opts and opts.on_update then
      vim.schedule(opts.on_update)
    end
  end

  stdout:read_start(function(err, data)
    assert(not err, err)
    if data then
      output = output .. data
    else
      process()
      stdout:close()
    end
  end)
end

---@param cwd string
---@param results snacks.explorer.git.Status[]
function M._update(cwd, results)
  local Tree = require("snacks.explorer.tree")
  local Git = require("snacks.picker.source.git")
  local node = Tree:find(cwd)

  local snapshot = Tree:snapshot(node, { "status", "ignored" })

  Tree:walk(node, function(n)
    n.status = nil
    n.ignored = nil
  end, { all = true })

  ---@param path string
  ---@param status string
  local function add_git_status(path, status)
    local n = Tree:find(path)
    n.status = n.status and Git.merge_status(n.status, status) or status
    if status:sub(1, 1) == "!" then
      n.ignored = true
    end
  end

  if vim.fn.isdirectory(cwd .. "/.git") == 1 then
    add_git_status(cwd .. "/.git", "!!")
  end

  for _, s in ipairs(results) do
    local is_dir = s.file:sub(-1) == "/"
    local path = is_dir and s.file:sub(1, -2) or s.file
    local deleted = s.status:find("D") and s.status ~= "UD"
    if not deleted then
      add_git_status(path, s.status)
    end
    if is_dir then
      local n = Tree:find(path)
      n.dir_status = s.status
    end
    if s.status:sub(1, 1) ~= "!" then -- don't propagate ignored status
      add_git_status(cwd, s.status)
      for dir in Snacks.picker.util.parents(path, cwd) do
        add_git_status(dir, s.status)
      end
    end
  end
  return Tree:changed(node, snapshot)
end

---@param cwd string
---@param path? string
---@param up? boolean
function M.next(cwd, path, up)
  local Tree = require("snacks.explorer.tree")
  return Tree:next(cwd, function(node)
    return node.status ~= nil
  end, { up = up, path = path })
end

return M
