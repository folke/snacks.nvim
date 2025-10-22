---@class snacks.git
local M = {}

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
local function is_git_root(dir)
  if git_cache[dir] == nil then
    git_cache[dir] = (vim.uv or vim.loop).fs_stat(dir .. "/.git") ~= nil
  end
  return git_cache[dir]
end

--- Gets the git root for a buffer or path.
--- Defaults to the current buffer.
---@param path? number|string buffer or path
---@return string?
function M.get_root(path)
  path = path or 0
  path = type(path) == "number" and vim.api.nvim_buf_get_name(path) or path --[[@as string]]
  path = path == "" and (vim.uv or vim.loop).cwd() or path
  path = svim.fs.normalize(path)

  if is_git_root(path) then
    return path
  end

  for dir in vim.fs.parents(path) do
    if is_git_root(dir) then
      return svim.fs.normalize(dir)
    end
  end

  return os.getenv("GIT_WORK_TREE")
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
