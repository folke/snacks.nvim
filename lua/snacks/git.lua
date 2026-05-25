---@class snacks.git
local M = {}
local uv = vim.uv or vim.loop

M.meta = {
  desc = "Git utilities",
}

Snacks.config.style("blame_line", {
  width = 0.6,
  height = 0.6,
  border = true,
  title = " Git Blame ",
  title_pos = "center",
  ft = "git",
})

local git_cache = {} ---@type table<string, boolean>
local git_dir_cache = {} ---@type table<string, string|false>
local function is_git_root(dir)
  if git_cache[dir] == nil then
    git_cache[dir] = uv.fs_stat(dir .. "/.git") ~= nil
  end
  return git_cache[dir]
end

---@param root string
---@return string?
local function get_root_git_dir(root)
  local cached = git_dir_cache[root]
  if cached ~= nil then
    return cached or nil
  end

  local env_work_tree = os.getenv("GIT_WORK_TREE")
  local env_git_dir = os.getenv("GIT_DIR")
  if env_work_tree and env_work_tree ~= "" and env_git_dir and env_git_dir ~= "" then
    if svim.fs.normalize(env_work_tree) == root then
      local git_dir = svim.fs.normalize(env_git_dir, { _fast = true })
      if not git_dir:match("^/") then
        git_dir = svim.fs.normalize(root .. "/" .. git_dir, { _fast = true })
      end
      git_dir_cache[root] = git_dir
      return git_dir
    end
  end

  local dot_git = root .. "/.git"
  local stat = uv.fs_stat(dot_git)
  if stat and stat.type == "directory" then
    git_dir_cache[root] = dot_git
    return dot_git
  end

  if stat and stat.type == "file" then
    local fd = uv.fs_open(dot_git, "r", 438)
    if fd then
      local git_stat = uv.fs_fstat(fd)
      local data = git_stat and uv.fs_read(fd, git_stat.size, 0) or nil
      uv.fs_close(fd)
      local git_dir = data and data:match("^gitdir:%s*(.-)%s*$")
      if git_dir and git_dir ~= "" then
        git_dir = svim.fs.normalize(git_dir, { _fast = true })
        if not git_dir:match("^/") then
          git_dir = svim.fs.normalize(root .. "/" .. git_dir, { _fast = true })
        end
        git_dir_cache[root] = git_dir
        return git_dir
      end
    end
  end

  git_dir_cache[root] = false
end

--- Gets the git root for a buffer or path.
--- Defaults to the current buffer.
---@param path? number|string buffer or path
---@return string?
function M.get_root(path)
  path = path or 0
  path = type(path) == "number" and vim.api.nvim_buf_get_name(path) or path --[[@as string]]
  path = path == "" and uv.cwd() or path
  path = svim.fs.normalize(path)

  if is_git_root(path) then
    return path
  end

  for dir in vim.fs.parents(path) do
    if is_git_root(dir) then
      return svim.fs.normalize(dir)
    end
  end

  local work_tree = os.getenv("GIT_WORK_TREE")
  return work_tree and work_tree ~= "" and svim.fs.normalize(work_tree) or nil
end

---@param path? number|string buffer or path
---@return string?
function M.get_dir(path)
  local root = M.get_root(path)
  if not root then
    return
  end
  return get_root_git_dir(root)
end

--- Show git log for the current line.
---@param opts? snacks.terminal.Opts | {count?: number}
function M.blame_line(opts)
  opts = vim.tbl_deep_extend("force", {
    count = 5,
    interactive = false,
    win = { style = "blame_line" },
  }, opts or {})
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]
  local file = vim.api.nvim_buf_get_name(0)
  local root = M.get_root()
  local cmd = { "git", "-C", root, "log", "-n", opts.count, "-u", "-L", line .. ",+1:" .. file }
  return Snacks.terminal(cmd, opts)
end

return M
