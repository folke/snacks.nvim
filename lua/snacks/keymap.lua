---@class snacks.keymap
local M = {}

M.meta = {
  desc = "Better `vim.keymap` with support for filetypes and LSP clients",
  needs_setup = false,
}

---@class snacks.keymap.set.Opts: vim.keymap.set.Opts
---@field ft? string|string[] Filetype(s) to set the keymap for.
---@field lsp? vim.lsp.get_clients.Filter Set for buffers with LSP clients matching this filter.
---@field enabled? boolean|fun(buf?:number): boolean condition to enable the keymap.

---@class snacks.keymap.del.Opts: vim.keymap.del.Opts
---@field buffer? boolean|number If true or 0, use the current buffer.
---@field ft? string|string[] Filetype(s) to set the keymap for.
---@field lsp? vim.lsp.get_clients.Filter Set for buffers with LSP clients matching this filter.

---@class snacks.Keymap
---@field mode string|string[] Mode "short-name" (see |nvim_set_keymap()|), or a list thereof.
---@field lhs string           Left-hand side |{lhs}| of the mapping.
---@field rhs string|function  Right-hand side |{rhs}| of the mapping, can be a Lua function.
---@field opts? snacks.keymap.set.Opts
---@field enabled fun(buf?:number): boolean

local by_ft = {} ---@type table<string, table<string,snacks.Keymap>>
local by_lsp = {} ---@type table<string, table<string,snacks.Keymap>>
local valid = {
  buffer = true,
  desc = true,
  callback = true,
  remap = true,
  silent = true,
  expr = true,
  nowait = true,
  unique = true,
  script = true,
  replace_keycodes = true,
  noremap = true,
}
local did_setup = false

---@param buf number
local function on_ft(buf)
  local ft = vim.bo[buf].filetype
  for _, map in pairs(by_ft[ft] or {}) do
    if map.enabled(buf) then
      vim.keymap.set(map.mode, map.lhs, map.rhs, Snacks.config.merge(map.opts or {}, { buffer = buf }))
    end
  end
end

local function setup()
  if did_setup then
    return
  end
  did_setup = true
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("snacks.keymap.ft", { clear = true }),
    callback = function(ev)
      on_ft(ev.buf)
    end,
  })
end

---@param filter vim.lsp.get_clients.Filter
local function lsp_key(filter)
  return vim.inspect(filter)
end

---@generic T: snacks.keymap.set.Opts|snacks.keymap.del.Opts
---@param ... T
---@return T opts, string[]? fts, vim.lsp.get_clients.Filter? lsp, fun(buf?:number) enabled
local function get_opts(...)
  ---@type snacks.keymap.set.Opts|snacks.keymap.del.Opts
  local opts = Snacks.config.merge({}, ...)
  opts.silent = opts.silent ~= false
  opts.buffer = (opts.buffer == 0 or opts.buffer == true) and vim.api.nvim_get_current_buf() or opts.buffer
  local fts = opts.ft and (type(opts.ft) == "table" and opts.ft or { opts.ft }) or nil --[[@as string[] ]]
  local lsp = opts.lsp
  local ret = vim.deepcopy(opts) ---@type table<string, any>
  for k in pairs(ret) do
    if not valid[k] then
      ret[k] = nil
    end
  end
  local enabled = function(buf)
    if type(opts.enabled) == "function" then
      return opts.enabled(buf)
    end
    return opts.enabled ~= false
  end
  return ret, fts, lsp, enabled
end

---@param mode string|string[] Mode "short-name" (see |nvim_set_keymap()|), or a list thereof.
---@param lhs string           Left-hand side |{lhs}| of the mapping.
---@param rhs string|function  Right-hand side |{rhs}| of the mapping, can be a Lua function.
---@param opts? snacks.keymap.set.Opts
function M.set(mode, lhs, rhs, opts)
  if type(mode) == "table" then
    for _, m in ipairs(mode) do
      M.set(m, lhs, rhs, opts)
    end
    return
  end

  local _opts, fts, lsp, enabled = get_opts(opts)

  ---@type snacks.Keymap
  local km = { mode = mode, lhs = lhs, rhs = rhs, opts = _opts, enabled = enabled }
  local key = ("%s:%s"):format(mode, lhs)

  if lsp then
    local lkey = lsp_key(lsp)
    if not by_lsp[lkey] then
      by_lsp[lkey] = {}
      Snacks.util.lsp.on(lsp, function(buf)
        for _, map in pairs(by_lsp[lkey]) do
          if map.enabled(buf) then
            vim.keymap.set(map.mode, map.lhs, map.rhs, Snacks.config.merge(map.opts or {}, { buffer = buf }))
          end
        end
      end)
    end
    by_lsp[lkey][key] = km
  elseif fts then
    setup()
    for _, ft in ipairs(fts) do
      by_ft[ft] = by_ft[ft] or {}
      by_ft[ft][key] = km
    end
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) and vim.tbl_contains(fts, vim.bo[buf].filetype) then
        on_ft(buf)
      end
    end
  else
    if
      enabled(_opts and _opts.buffer or nil --[[@as integer?]])
    then
      vim.keymap.set(mode, lhs, rhs, _opts)
    end
  end
end

---@param mode string|string[] Mode "short-name" (see |nvim_set_keymap()|), or a list thereof.
---@param lhs string           Left-hand side |{lhs}| of the mapping.
---@param opts? snacks.keymap.del.Opts
function M.del(mode, lhs, opts)
  if type(mode) == "table" then
    for _, m in ipairs(mode) do
      M.del(m, lhs, opts)
    end
    return
  end

  local _opts, fts, lsp = get_opts(opts)
  local key = ("%s:%s"):format(mode, lhs)

  if lsp then
    local lkey = lsp_key(lsp)
    if by_lsp[lkey] then
      by_lsp[lkey][key] = nil
    end
  elseif fts then
    for _, ft in ipairs(fts) do
      if by_ft[ft] then
        by_ft[ft][key] = nil
      end
    end
  else
    vim.keymap.del(mode, lhs, _opts)
  end
end

return M
