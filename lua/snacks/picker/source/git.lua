local M = {}

local uv = vim.uv or vim.loop

---@class snacks.picker
---@field git_files fun(opts?: snacks.picker.git.files.Config): snacks.Picker
---@field git_log fun(opts?: snacks.picker.git.log.Config): snacks.Picker
---@field git_log_file fun(opts?: snacks.picker.git.log.Config): snacks.Picker
---@field git_log_line fun(opts?: snacks.picker.git.log.Config): snacks.Picker
---@field git_status fun(opts?: snacks.picker.Config): snacks.Picker

---@param opts snacks.picker.git.files.Config
---@type snacks.picker.finder
function M.files(opts)
  local args = { "-c", "core.quotepath=false", "ls-files", "--exclude-standard", "--cached" }
  if opts.untracked then
    table.insert(args, "--others")
  elseif opts.submodules then
    table.insert(args, "--recurse-submodules")
  end
  local cwd = vim.fs.normalize(opts and opts.cwd or uv.cwd() or ".") or nil
  return require("snacks.picker.source.proc").proc(vim.tbl_deep_extend("force", {
    cmd = "git",
    args = args,
    ---@param item snacks.picker.finder.Item
    transform = function(item)
      item.cwd = cwd
      item.file = item.text
    end,
  }, opts or {}))
end

---@param opts snacks.picker.git.log.Config
---@type snacks.picker.finder
function M.log(opts)
  local args = {
    "log",
    "--pretty=format:%h %s (%ch)",
    "--abbrev-commit",
    "--decorate",
    "--date=short",
    "--color=never",
    "--no-show-signature",
    "--no-patch",
  }

  if opts.follow and not opts.current_line then
    args[#args + 1] = "--follow"
  end

  if opts.current_line then
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line = cursor[1]
    args[#args + 1] = "-L"
    args[#args + 1] = line .. ",+1:" .. vim.api.nvim_buf_get_name(0)
  elseif opts.current_file then
    args[#args + 1] = "--"
    args[#args + 1] = vim.api.nvim_buf_get_name(0)
  end

  local cwd = vim.fs.normalize(opts and opts.cwd or uv.cwd() or ".") or nil
  return require("snacks.picker.source.proc").proc(vim.tbl_deep_extend("force", {
    cmd = "git",
    args = args,
    ---@param item snacks.picker.finder.Item
    transform = function(item)
      local commit, msg, date = item.text:match("^(%S+) (.*) %((.*)%)$")
      if not commit then
        error(item.text)
      end
      item.cwd = cwd
      item.commit = commit
      item.msg = msg
      item.date = date
      item.file = item.text
    end,
  }, opts or {}))
end

---@param opts snacks.picker.Config
---@type snacks.picker.finder
function M.status(opts)
  local args = {
    "status",
    "--porcelain=v1",
  }

  local cwd = vim.fs.normalize(opts and opts.cwd or uv.cwd() or ".") or nil
  cwd = Snacks.git.get_root(cwd)
  return require("snacks.picker.source.proc").proc(vim.tbl_deep_extend("force", {
    cmd = "git",
    args = args,
    ---@param item snacks.picker.finder.Item
    transform = function(item)
      local status, file = item.text:sub(1, 2), item.text:sub(4)
      item.cwd = cwd
      item.status = status
      item.file = file
    end,
  }, opts or {}))
end

return M
