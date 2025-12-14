local Git = require("snacks.explorer.git")
local Tree = require("snacks.explorer.tree")

---@class snacks.explorer.diagnostic.Action: snacks.picker.Action
---@field severity? number
---@field up? boolean

local uv = vim.uv or vim.loop

local M = {}

---@param path string
function M.get_trash_cmds(path)
  ---@type string[][]
  local ret = {
    { "trash", path }, -- trash-cli (Python or Node.js)
    { "gio", "trash", path }, -- Most universally available on modern Linux
    { "kioclient5", "move", path, "trash:/" }, -- KDE Plasma 5
    { "kioclient", "move", path, "trash:/" }, -- KDE Plasma 6
  }
  if vim.fn.has("win32") == 1 then
    ret[#ret + 1] = {
      "powershell",
      "-NoProfile",
      "-Command",
      (
        "Add-Type -AssemblyName Microsoft.VisualBasic; "
        .. "[Microsoft.VisualBasic.FileIO.FileSystem]::"
        .. (vim.fn.isdirectory(path) == 0 and "DeleteFile" or "DeleteDirectory")
        .. "('%s','OnlyErrorDialogs', 'SendToRecycleBin')"
      ):format(path:gsub("\\", "\\\\"):gsub("'", "''")),
    }
  end
  return ret
end

---@param path string
function M.trash(path)
  if Snacks.explorer.config.trash then
    for _, cmd in ipairs(M.get_trash_cmds(path)) do
      if vim.fn.executable(cmd[1]) == 1 then
        local ok, ret = pcall(vim.fn.system, cmd)
        if not ok or vim.v.shell_error ~= 0 then
          return false,
            ("- cmd: `%s`\n- error: %s"):format(
              table.concat(cmd, " "),
              type(ret) == "string" and ret or "Unknown error"
            )
        end
        return true
      end
    end
  end

  -- Fallback to delete
  local ok, ret = pcall(vim.fn.delete, path, "rf")
  if not ok or ret ~= 0 then
    return false, type(ret) == "string" and ret or "Unknown error"
  end
  return true
end

---@param picker snacks.Picker
---@param path string
function M.reveal(picker, path)
  if picker.closed then
    return
  end
  for item, idx in picker:iter() do
    if item.file == path then
      picker.list:view(idx)
      return true
    end
  end
end

---@param picker snacks.Picker
---@param opts? {target?: boolean|string, refresh?: boolean}
function M.update(picker, opts)
  opts = opts or {}
  local cwd = picker:cwd()
  local target = type(opts.target) == "string" and opts.target or nil --[[@as string]]
  local refresh = opts.refresh or Tree:is_dirty(cwd, picker.opts)
  if target and not Tree:is_visible(cwd, target) then
    Tree:open(target)
    refresh = true
  end

  -- when searching, restore explorer view first
  if picker.input.filter.meta.searching then
    picker.input:set("", "")
    picker.list.win:focus()
    refresh = true
  end

  if not refresh and target then
    return M.reveal(picker, target)
  end
  if opts.target ~= false then
    picker.list:set_target()
  end
  picker:find({
    on_done = function()
      if target then
        M.reveal(picker, target)
      end
    end,
  })
end

---@class snacks.explorer.actions
---@field [string] snacks.picker.Action.spec
M.actions = {}

function M.actions.explorer_focus(picker)
  picker:set_cwd(picker:dir())
  picker:find()
end

function M.actions.explorer_open(_, item)
  if item then
    local _, err = vim.ui.open(item.file)
    if err then
      Snacks.notify.error("Failed to open `" .. item.file .. "`:\n- " .. err)
    end
  end
end

function M.actions.explorer_yank(picker)
  local files = {} ---@type string[]
  if vim.fn.mode():find("^[vV]") then
    picker.list:select()
  end
  for _, item in ipairs(picker:selected({ fallback = true })) do
    table.insert(files, Snacks.picker.util.path(item))
  end
  picker.list:set_selected() -- clear selection
  local value = table.concat(files, "\n")
  vim.fn.setreg(vim.v.register or "+", value, "l")
  Snacks.notify.info("Yanked " .. #files .. " files")
end

function M.actions.explorer_up(picker)
  picker:set_cwd(vim.fs.dirname(picker:cwd()))
  picker:find()
end

function M.actions.explorer_close(picker, item)
  if not item then
    return
  end
  local dir = picker:dir()
  if item.dir and not item.open then
    dir = vim.fs.dirname(dir)
  end
  Tree:close(dir)
  M.update(picker, { target = dir, refresh = true })
end

function M.actions.explorer_update(picker)
  Tree:refresh(picker:cwd())
  M.update(picker)
end

function M.actions.explorer_close_all(picker)
  Tree:close_all(picker:cwd())
  M.update(picker, { refresh = true })
end

function M.actions.explorer_git_next(picker, item)
  local node = Git.next(picker:cwd(), item and item.file)
  if node then
    M.update(picker, { target = node.path })
  end
end

function M.actions.explorer_paste(picker)
  local files = vim.split(vim.fn.getreg(vim.v.register or "+") or "", "\n", { plain = true })
  files = vim.tbl_filter(function(file)
    return file ~= "" and vim.fn.filereadable(file) == 1
  end, files)

  if #files == 0 then
    return Snacks.notify.warn(("The `%s` register does not contain any files"):format(vim.v.register or "+"))
  end
  local dir = picker:dir()
  Snacks.picker.util.copy(files, dir)
  Tree:refresh(dir)
  Tree:open(dir)
  M.update(picker, { target = dir })
end

function M.actions.explorer_git_prev(picker, item)
  local node = Git.next(picker:cwd(), item and item.file, true)
  if node then
    M.update(picker, { target = node.path })
  end
end

function M.actions.explorer_add(picker)
  Snacks.input({
    prompt = 'Add a new file or directory (directories end with a "/")',
  }, function(value)
    if not value or value:find("^%s$") then
      return
    end
    local path = svim.fs.normalize(picker:dir() .. "/" .. value)
    local is_file = value:sub(-1) ~= "/"
    local dir = is_file and vim.fs.dirname(path) or path
    if is_file and uv.fs_stat(path) then
      Snacks.notify.warn("File already exists:\n- `" .. path .. "`")
      return
    end
    vim.fn.mkdir(dir, "p")
    if is_file then
      io.open(path, "w"):close()
    end
    Tree:open(dir)
    Tree:refresh(dir)
    M.update(picker, { target = path })
  end)
end

function M.actions.explorer_rename(picker, item)
  if not item then
    return
  end
  Snacks.rename.rename_file({
    from = item.file,
    on_rename = function(new, old)
      Tree:refresh(vim.fs.dirname(old))
      Tree:refresh(vim.fs.dirname(new))
      M.update(picker, { target = new })
    end,
  })
end

function M.actions.explorer_move(picker)
  ---@type string[]
  local paths = vim.tbl_map(Snacks.picker.util.path, picker:selected())
  if #paths == 0 then
    Snacks.notify.warn("No files selected to move. Renaming instead.")
    return M.actions.explorer_rename(picker, picker:current())
  end
  local target = picker:dir()
  local what = #paths == 1 and vim.fn.fnamemodify(paths[1], ":p:~:.") or #paths .. " files"
  local t = vim.fn.fnamemodify(target, ":p:~:.")

  Snacks.picker.util.confirm("Move " .. what .. " to " .. t .. "?", function()
    for _, from in ipairs(paths) do
      local to = target .. "/" .. vim.fn.fnamemodify(from, ":t")
      Snacks.rename.rename_file({ from = from, to = to })
      Tree:refresh(vim.fs.dirname(from))
    end
    Tree:refresh(target)
    picker.list:set_selected() -- clear selection
    M.update(picker, { target = target })
  end)
end

function M.actions.explorer_copy(picker, item)
  if not item then
    return
  end
  ---@type string[]
  local paths = vim.tbl_map(Snacks.picker.util.path, picker:selected())
  -- Copy selection
  if #paths > 0 then
    local dir = picker:dir()
    Snacks.picker.util.copy(paths, dir)
    picker.list:set_selected() -- clear selection
    Tree:refresh(dir)
    Tree:open(dir)
    M.update(picker, { target = dir })
    return
  end
  Snacks.input({
    prompt = "Copy to",
  }, function(value)
    if not value or value:find("^%s$") then
      return
    end
    local dir = vim.fs.dirname(item.file)
    local to = svim.fs.normalize(dir .. "/" .. value)
    if uv.fs_stat(to) then
      Snacks.notify.warn("File already exists:\n- `" .. to .. "`")
      return
    end
    Snacks.picker.util.copy_path(item.file, to)
    Tree:refresh(vim.fs.dirname(to))
    M.update(picker, { target = to })
  end)
end

function M.actions.explorer_del(picker)
  ---@type string[]
  local paths = vim.tbl_map(Snacks.picker.util.path, picker:selected({ fallback = true }))
  if #paths == 0 then
    return
  end
  local what = #paths == 1 and vim.fn.fnamemodify(paths[1], ":p:~:.") or #paths .. " files"
  Snacks.picker.util.confirm("Delete " .. what .. "?", function()
    for _, path in ipairs(paths) do
      local ok, err = M.trash(path)
      if ok then
        Snacks.bufdelete({ file = path, force = true })
      else
        Snacks.notify.error("Failed to delete `" .. path .. "`:\n" .. err)
      end
      Tree:refresh(vim.fs.dirname(path))
    end
    picker.list:set_selected() -- clear selection
    M.update(picker)
  end)
end

function M.actions.confirm(picker, item, action)
  if not item then
    return
  elseif picker.input.filter.meta.searching then
    M.update(picker, { target = item.file })
  elseif item.dir then
    Tree:toggle(item.file)
    M.update(picker, { refresh = true })
  else
    Snacks.picker.actions.jump(picker, item, action)
  end
end

function M.actions.explorer_diagnostic(picker, item, action)
  ---@cast action snacks.explorer.diagnostic.Action
  local node = Tree:next(picker:cwd(), function(node)
    if not node.severity then
      return false
    end
    return action.severity == nil or node.severity == action.severity
  end, { up = action.up, path = item and item.file })
  if node then
    M.update(picker, { target = node.path })
  end
end

M.actions.explorer_diagnostic_next = { action = "explorer_diagnostic" }
M.actions.explorer_diagnostic_prev = { action = "explorer_diagnostic", up = true }
M.actions.explorer_warn_next = { action = "explorer_diagnostic", severity = vim.diagnostic.severity.WARN }
M.actions.explorer_warn_prev = { action = "explorer_diagnostic", severity = vim.diagnostic.severity.WARN, up = true }
M.actions.explorer_error_next = { action = "explorer_diagnostic", severity = vim.diagnostic.severity.ERROR }
M.actions.explorer_error_prev = { action = "explorer_diagnostic", severity = vim.diagnostic.severity.ERROR, up = true }

return M
