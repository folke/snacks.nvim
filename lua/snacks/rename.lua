---@class snacks.rename
local M = {}

M.meta = {
  desc = "LSP-integrated file renaming with support for plugins like [neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim) and [mini.files](https://github.com/nvim-mini/mini.files).",
}

-- Renames the provided file, or the current buffer's file.
-- Prompt for the new filename if `to` is not provided.
-- do the rename, and trigger LSP handlers
---@param opts? {from?: string, to?:string, on_rename?: fun(to:string, from:string, ok:boolean)}
function M.rename_file(opts)
  opts = opts or {}
  local from = vim.fn.fnamemodify(opts.from or opts.file or vim.api.nvim_buf_get_name(0), ":p")
  local to = opts.to and vim.fn.fnamemodify(opts.to, ":p") or nil

  local function rename()
    assert(to, "to is required")
    M.on_rename_file(from, to, function()
      local ok = M._rename(from, to)
      if opts.on_rename then
        opts.on_rename(to, from, ok)
      end
    end)
  end

  if to then
    return rename()
  end

  local root = vim.fn.getcwd()

  if from:find(root, 1, true) ~= 1 then
    root = vim.fn.fnamemodify(from, ":p:h")
  end

  local extra = from:sub(#root + 2)

  vim.ui.input({
    prompt = "New File Name: ",
    default = extra,
    completion = "file",
  }, function(value)
    if not value or value == "" or value == extra then
      return
    end
    to = svim.fs.normalize(root .. "/" .. value)
    rename()
  end)
end

--- Rename a file and update buffers
---@param from string
---@param to string
---@return boolean ok
function M._rename(from, to)
  from = vim.fn.fnamemodify(from, ":p")
  to = vim.fn.fnamemodify(to, ":p")
  -- rename the file
  local ret = vim.fn.rename(from, to)
  if ret ~= 0 then
    Snacks.notify.error("Failed to rename file: `" .. from .. "`")
    return false
  end

  -- replace buffer in all windows
  local from_buf = vim.fn.bufnr(from)
  if from_buf >= 0 then
    local to_buf = vim.fn.bufadd(to)
    vim.bo[to_buf].buflisted = true
    for _, win in ipairs(vim.fn.win_findbuf(from_buf)) do
      vim.api.nvim_win_call(win, function()
        vim.cmd("buffer " .. to_buf)
      end)
    end
    vim.api.nvim_buf_delete(from_buf, { force = true })
  end
  return true
end

--- Lets LSP clients know that a file has been renamed
---@param from string
---@param to string
---@param rename? fun()
function M.on_rename_file(from, to, rename)
  local changes = { files = { {
    oldUri = vim.uri_from_fname(from),
    newUri = vim.uri_from_fname(to),
  } } }

  local clients = (vim.lsp.get_clients or vim.lsp.get_active_clients)()
  for _, client in ipairs(clients) do
    if client.supports_method("workspace/willRenameFiles") then
      local resp = client.request_sync("workspace/willRenameFiles", changes, 1000, 0)
      if resp and resp.result ~= nil then
        vim.lsp.util.apply_workspace_edit(resp.result, client.offset_encoding)
      end
    end
  end

  if rename then
    rename()
  end

  for _, client in ipairs(clients) do
    if client.supports_method("workspace/didRenameFiles") then
      client.notify("workspace/didRenameFiles", changes)
    end
  end
end

return M
