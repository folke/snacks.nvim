---@class snacks.words
local M = {}

M.meta = {
  desc = "Auto-show LSP references and quickly navigate between them",
  needs_setup = true,
}

---@private
---@alias LspWord {from:{[1]:number, [2]:number}, to:{[1]:number, [2]:number}} 1-0 indexed

---@class snacks.words.Config
---@field enabled? boolean
local defaults = {
  debounce = 200, -- time in ms to wait before updating
  notify_jump = false, -- show a notification when jumping
  notify_end = true, -- show a notification when reaching the end
  foldopen = true, -- open folds after jumping
  jumplist = true, -- set jump point before jumping
  modes = { "n", "i", "c" }, -- modes to show references
}

M.enabled = false

local config = Snacks.config.get("words", defaults)
local ns = vim.api.nvim_create_namespace("vim_lsp_references")
local timer = (vim.uv or vim.loop).new_timer()

function M.enable()
  if M.enabled then
    return
  end
  M.enabled = true
  local group = vim.api.nvim_create_augroup("snacks_words", { clear = true })

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "ModeChanged" }, {
    group = group,
    callback = function()
      if not M.is_enabled() then
        M.clear()
        return
      end
      if not ({ M.get() })[2] then
        M.update()
      end
    end,
  })
end

function M.disable()
  if not M.enabled then
    return
  end
  M.enabled = false
  vim.api.nvim_del_augroup_by_name("snacks_words")
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  end
end

function M.clear()
  vim.lsp.buf.clear_references()
end

---@private
function M.update()
  local buf = vim.api.nvim_get_current_buf()
  timer:start(config.debounce, 0, function()
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_call(buf, function()
          if not M.is_enabled() then
            return
          end
          vim.lsp.buf.document_highlight()
          M.clear()
        end)
      end
    end)
  end)
end

---@param buf number?
function M.is_enabled(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local mode = vim.api.nvim_get_mode().mode:lower()
  mode = mode:gsub("\22", "v"):gsub("\19", "s")
  mode = mode:sub(1, 2) == "no" and "o" or mode
  mode = mode:sub(1, 1):match("[ncitsvo]") or "n"
  local clients = (vim.lsp.get_clients or vim.lsp.get_active_clients)({ bufnr = buf })
  clients = vim.tbl_filter(function(client)
    return client.supports_method("textDocument/documentHighlight", { bufnr = buf })
  end, clients)
  return M.enabled and vim.tbl_contains(config.modes, mode) and #clients > 0
end

---@private
---@return LspWord[] words, number? current
function M.get()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local current, ret = nil, {} ---@type number?, LspWord[]
  for _, extmark in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })) do
    local w = {
      from = { extmark[2] + 1, extmark[3] },
      to = { extmark[4].end_row + 1, extmark[4].end_col },
    }
    ret[#ret + 1] = w
    if cursor[1] >= w.from[1] and cursor[1] <= w.to[1] and cursor[2] >= w.from[2] and cursor[2] <= w.to[2] then
      current = #ret
    end
  end
  return ret, current
end

---@param count number
---@param cycle? boolean
function M.jump(count, cycle)
  local words, idx = M.get()
  if not idx then
    return
  end
  idx = idx + count
  if cycle then
    idx = (idx - 1) % #words + 1
  end
  local target = words[idx]
  if target then
    if config.jumplist then
      vim.cmd.normal({ "m`", bang = true })
    end
    vim.api.nvim_win_set_cursor(0, target.from)
    if config.notify_jump then
      Snacks.notify.info(("Reference [%d/%d]"):format(idx, #words), { id = "snacks.words.jump", title = "Words" })
    end
    if config.foldopen then
      vim.cmd.normal({ "zv", bang = true })
    end
  elseif config.notify_end then
    Snacks.notify.warn("No more references", { id = "snacks.words.jump", title = "Words" })
  end
end

return M
