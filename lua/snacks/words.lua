---@hide
---@class snacks.words
local M = {}

---@private
---@alias LspWord {from:{[1]:number, [2]:number}, to:{[1]:number, [2]:number}} 1-0 indexed

---@class snacks.words.Config
local defaults = {
  enabled = true, -- enable/disable the plugin
  debounce = 200, -- time in ms to wait before updating
}

local config = Snacks.config.get("words", defaults)
local ns = vim.api.nvim_create_namespace("vim_lsp_references")
local timer = (vim.uv or vim.loop).new_timer()

---@private
function M.setup()
  local group = vim.api.nvim_create_augroup("snacks_words", { clear = true })

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = group,
    callback = function()
      if not ({ M.get() })[2] then
        M.update()
      end
    end,
  })
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
          vim.lsp.buf.clear_references()
        end)
      end
    end)
  end)
end

---@param buf number?
function M.is_enabled(buf)
  return config.enabled
    and #vim.lsp.get_clients({
        method = vim.lsp.protocol.Methods.textDocument_documentHighlight,
        bufnr = buf or 0,
      })
      > 0
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
---@param notify? boolean
function M.jump(count, cycle, notify)
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
    vim.api.nvim_win_set_cursor(0, target.from)
    if notify then
      Snacks.notify.info(("Reference %d/%d"):format(idx, #words), { id = "snacks.words.jump" })
    end
  end
end

return M
