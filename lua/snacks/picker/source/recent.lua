local M = {}

local uv = vim.uv or vim.loop

---@class snacks.picker
---@field recent fun(opts?: snacks.picker.recent.Config): snacks.Picker
---@field projects fun(opts?: snacks.picker.projects.Config): snacks.Picker

---@param filter snacks.picker.Filter
---@param extra? string[]
local function oldfiles(filter, extra)
  local done = {} ---@type table<string, boolean>
  local files = {} ---@type string[]
  vim.list_extend(files, extra or {})
  vim.list_extend(files, vim.v.oldfiles)
  return function()
    for _, file in ipairs(files) do
      file = vim.fs.normalize(file, { _fast = true, expand_env = false })
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
function M.files(opts, filter)
  local current_file = vim.fs.normalize(vim.api.nvim_buf_get_name(0), { _fast = true })
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
    for file in oldfiles(filter, extra) do
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
---@param opts snacks.picker.recent.Config
---@type snacks.picker.finder
function M.projects(opts, filter)
  ---@async
  ---@param cb async fun(item: snacks.picker.finder.Item)
  return function(cb)
    local dirs = {} ---@type table<string, boolean>
    for file in oldfiles(filter) do
      local dir = Snacks.git.get_root(file)
      if dir and not dirs[dir] then
        dirs[dir] = true
        cb({ file = dir, text = file, dir = dir })
      end
    end
  end
end

return M
