local M = {}

local uv = vim.uv or vim.loop

---@param filter snacks.picker.Filter
---@param extra? string[]
local function oldfiles(filter, extra)
  local done = {} ---@type table<string, boolean>
  local files = {} ---@type string[]
  vim.list_extend(files, extra or {})
  vim.list_extend(files, vim.v.oldfiles)
  local i = 0
  return function()
    for f = i + 1, #files do
      i = f
      local file = files[f]
      file = vim.fn.fnamemodify(file, ":p")
      file = svim.fs.normalize(file, { _fast = true, expand_env = false })
      local want = not done[file] and filter:match({ file = file, text = "" })
      done[file] = true
      if want and uv.fs_stat(file) then
        return file
      end
    end
  end
end

--- Get the most recent files, optionally filtered by the
--- current working directory or a custom directory.
---@param opts snacks.picker.recent.Config
---@type snacks.picker.finder
function M.files(opts, ctx)
  local current_file = svim.fs.normalize(vim.api.nvim_buf_get_name(0), { _fast = true })
  ---@type number[]
  local bufs = vim.tbl_filter(function(b)
    return vim.api.nvim_buf_get_name(b) ~= "" and vim.bo[b].buftype == "" and vim.bo[b].buflisted
  end, vim.api.nvim_list_bufs())
  table.sort(bufs, function(a, b)
    return vim.fn.getbufinfo(a)[1].lastused > vim.fn.getbufinfo(b)[1].lastused
  end)
  local extra = vim.tbl_map(function(b)
    return vim.api.nvim_buf_get_name(b)
  end, bufs)
  ---@async
  ---@param cb async fun(item: snacks.picker.finder.Item)
  return function(cb)
    for file in oldfiles(ctx.filter, extra) do
      if file ~= current_file then
        cb({ file = file, text = file, recent = true })
      end
    end
  end
end

M.recent = M.files

--- Get the most recent projects based on git roots of recent files.
--- The default action will change the directory to the project root,
--- try to restore the session and open the picker if the session is not restored.
--- You can customize the behavior by providing a custom action.
---@param opts snacks.picker.projects.Config
---@type snacks.picker.finder
function M.projects(opts, ctx)
  local args = {
    "-H",
    "-t",
    "f",
    "-t",
    "s",
    "-t",
    "d",
    "--max-depth",
    "2",
    "--follow",
    "--absolute-path",
  }
  vim.list_extend(args, { "-g", "{" .. table.concat(opts.patterns or {}, ",") .. "}" })
  local dev = type(opts.dev) == "string" and { opts.dev } or opts.dev or {}
  ---@cast dev string[]
  vim.list_extend(args, vim.tbl_map(svim.fs.normalize, dev))
  local fd = require("snacks.picker.source.files").get_fd()
  if not fd then
    Snacks.notify.warn("`fd` or `fdfind` is required for projects")
  end
  local proc = fd and require("snacks.picker.source.proc").proc({ cmd = fd, args = args, notify = false }, ctx)
  ---@async
  ---@param cb async fun(item: snacks.picker.finder.Item)
  return function(cb)
    local dirs = {} ---@type table<string, boolean>
    ---@async
    local function add(dir)
      if dir and not dirs[dir] then
        dirs[dir] = true
        cb({ file = dir, text = dir, dir = true })
      end
    end

    if opts.recent then
      for file in oldfiles(ctx.filter) do
        local dir = Snacks.git.get_root(file)
        add(dir)
      end
    end

    vim.tbl_map(add, opts.projects or {})

    if not proc then
      return
    end

    ---@async
    proc(function(item)
      local path = item.text
      path = path:sub(-1) == "/" and path:sub(1, -2) or path
      path = vim.fs.dirname(path)
      if ctx.filter:match({ file = path, text = path }) then
        add(path)
      end
    end)
  end
end

return M
