---@class snacks.bufdelete
---@overload fun(buf?: number|snacks.bufdelete.Opts)
local M = setmetatable({}, {
  __call = function(t, ...)
    return t.delete(...)
  end,
})

M.meta = {
  desc = "Delete buffers without disrupting window layout",
}

---@class snacks.bufdelete.Opts
---@field buf? number Buffer to delete. Defaults to the current buffer
---@field file? string Delete buffer by file name. If provided, `buf` is ignored
---@field force? boolean Delete the buffer even if it is modified
---@field filter? fun(buf: number): boolean Filter buffers to delete
---@field wipe? boolean Wipe the buffer instead of deleting it (see `:h :bwipeout`)

--- Delete a buffer:
--- - either the current buffer if `buf` is not provided
--- - or the buffer `buf` if it is a number
--- - or every buffer for which `buf` returns true if it is a function
---@param opts? number|snacks.bufdelete.Opts
function M.delete(opts)
  opts = opts or {}
  opts = type(opts) == "number" and { buf = opts } or opts
  opts = type(opts) == "function" and { filter = opts } or opts
  ---@cast opts snacks.bufdelete.Opts

  if type(opts.filter) == "function" then
    for _, b in ipairs(vim.tbl_filter(opts.filter, vim.api.nvim_list_bufs())) do
      if vim.bo[b].buflisted then
        M.delete(vim.tbl_extend("force", {}, opts, { buf = b, filter = false }))
      end
    end
    return
  end

  local buf = opts.buf or 0
  if opts.file then
    buf = vim.fn.bufnr(opts.file)
    if buf == -1 then
      return
    end
  end
  buf = buf == 0 and vim.api.nvim_get_current_buf() or buf

  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  -- Check if the buffer is modified
  if vim.bo[buf].modified and not opts.force then
    local ok, choice = pcall(vim.fn.confirm, ("Save changes to %q?"):format(vim.fn.bufname(buf)), "&Yes\n&No\n&Cancel")
    if not ok or choice == 0 or choice == 3 then -- 0 for <Esc>/<C-c> and 3 for Cancel
      return
    elseif choice == 1 then -- Yes
      vim.api.nvim_buf_call(buf, vim.cmd.write)
    end
  end

  -- Get the most recently used listed buffer that is not the one being deleted,
  local info = vim.fn.getbufinfo({ buflisted = 1 })
  ---@param b vim.fn.getbufinfo.ret.item
  info = vim.tbl_filter(function(b)
    return b.bufnr ~= buf
  end, info)
  table.sort(info, function(a, b)
    return a.lastused > b.lastused
  end)

  local new_buf = info[1] and info[1].bufnr or vim.api.nvim_create_buf(true, false)

  -- replace the buffer in all windows showing it,
  -- trying to use the alternate buffer if possible
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    local win_buf = new_buf
    vim.api.nvim_win_call(win, function() -- Try using alternate buffer
      local alt = vim.fn.bufnr("#")
      win_buf = alt >= 0 and alt ~= buf and vim.bo[alt].buflisted and alt or win_buf
    end)
    vim.api.nvim_win_set_buf(win, win_buf)
  end

  if vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.cmd, (opts.wipe and "bwipeout! " or "bdelete! ") .. buf)
  end
end

--- Delete all buffers
---@param opts? snacks.bufdelete.Opts
function M.all(opts)
  return M.delete(vim.tbl_extend("force", {}, opts or {}, {
    filter = function()
      return true
    end,
  }))
end

--- Delete all buffers except the current one
---@param opts? snacks.bufdelete.Opts
function M.other(opts)
  return M.delete(vim.tbl_extend("force", {}, opts or {}, {
    filter = function(b)
      return b ~= vim.api.nvim_get_current_buf()
    end,
  }))
end

return M
