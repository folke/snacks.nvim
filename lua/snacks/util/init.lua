---@class snacks.util
---@field spawn snacks.spawn
---@field lsp snacks.lsp
local M = setmetatable({}, {
  ---@param M snacks.util
  __index = function(M, k)
    if vim.tbl_contains({ "spawn", "lsp" }, k) then
      M[k] = require("snacks.util." .. k)
    end
    return rawget(M, k)
  end,
})

M.meta = {
  desc = "Utility functions for Snacks _(library)_",
}

M.is_win = jit.os:find("Windows")

local uv = vim.uv or vim.loop
local key_cache = {} ---@type table<string, string>
local langs = {} ---@type table<string, boolean>

---@alias snacks.util.hl table<string, string|vim.api.keyset.highlight>

local hl_groups = {} ---@type table<string, vim.api.keyset.highlight>
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("snacks_util_hl", { clear = true }),
  callback = function()
    for hl_group, hl in pairs(hl_groups) do
      vim.api.nvim_set_hl(0, hl_group, hl)
    end
  end,
})

---@param lang string|number|nil
---@overload fun(buf:number):string?
---@overload fun(ft:string):string?
---@return string?
function M.get_lang(lang)
  lang = type(lang) == "number" and vim.bo[lang].filetype or lang --[[@as string?]]
  lang = lang and vim.treesitter.language.get_lang(lang) or lang
  if lang and lang ~= "" and langs[lang] == nil then
    local ok, ret = pcall(vim.treesitter.language.add, lang)
    langs[lang] = (ok and ret) or (ok and vim.fn.has("nvim-0.11") == 0)
  end
  return langs[lang] and lang or nil
end

--- Ensures the hl groups are always set, even after a colorscheme change.
---@param groups snacks.util.hl
---@param opts? { prefix?:string, default?:boolean, managed?:boolean }
function M.set_hl(groups, opts)
  opts = opts or {}
  for hl_group, hl in pairs(groups) do
    hl_group = opts.prefix and opts.prefix .. hl_group or hl_group
    hl = type(hl) == "string" and { link = hl } or hl --[[@as vim.api.keyset.highlight]]
    hl.default = opts.default
    if opts.managed ~= false then
      hl_groups[hl_group] = hl
    end
    vim.api.nvim_set_hl(0, hl_group, hl)
  end
end

---@param group string|string[] hl group to get color from
---@param prop? string property to get. Defaults to "fg"
function M.color(group, prop)
  prop = prop or "fg"
  group = type(group) == "table" and group or { group }
  ---@cast group string[]
  for _, g in ipairs(group) do
    local hl = vim.api.nvim_get_hl(0, { name = g, link = false, create = false })
    if hl[prop] then
      return string.format("#%06x", hl[prop])
    end
  end
end

--- Set window-local options.
---@param win number
---@param wo vim.wo|{}|{winhighlight: string|table<string, string>}
function M.wo(win, wo)
  for k, v in pairs(wo or {}) do
    if k == "winhighlight" and type(v) == "table" then
      local parts = {} ---@type string[]
      for kk, vv in pairs(v) do
        if vv ~= "" then
          parts[#parts + 1] = ("%s:%s"):format(kk, vv)
        end
      end
      v = table.concat(parts, ",")
    end
    vim.api.nvim_set_option_value(k, v, { scope = "local", win = win })
  end
end

--- Set buffer-local options.
---@param buf number
---@param bo vim.bo|{}
function M.bo(buf, bo)
  for k, v in pairs(bo or {}) do
    vim.api.nvim_set_option_value(k, v, { buf = buf })
  end
end

--- Merges vim.wo.winhighlight options.
--- Option values can be a string or a dictionary.
---@param ... string|table<string, string>
function M.winhl(...)
  local ret = {} ---@type table<string, string>[]
  for i = 1, select("#", ...) do
    local winhl = select(i, ...)
    if type(winhl) == "string" then
      winhl = vim.trim(winhl)
      local parts = winhl == "" and {} or vim.split(winhl, ",")
      winhl = {}
      for _, p in ipairs(parts) do
        local k, v = p:match("^%s*(.-):(.-)%s*$")
        if k and v then
          winhl[k] = v
        end
      end
    end
    ret[#ret + 1] = winhl
  end
  return Snacks.config.merge(unpack(ret))
end

--- Get an icon from `mini.icons` or `nvim-web-devicons`.
---@param name string
---@param cat? string "file"|"filetype"|"extension"|"directory"
---@param opts? { fallback?: {dir?:string, file?:string} }
---@return string, string?
function M.icon(name, cat, opts)
  opts = opts or {}
  opts.fallback = opts.fallback or {}
  local try = {
    function()
      return MiniIcons.get(cat or "file", name)
    end,
    function()
      if cat == "directory" then
        return opts.fallback.dir or "󰉋 ", "Directory"
      end
      local Icons = require("nvim-web-devicons")
      if cat == "filetype" then
        return Icons.get_icon_by_filetype(name, { default = false })
      elseif cat == "file" then
        local ext = name:match("%.(%w+)$")
        return Icons.get_icon(name, ext, { default = false }) --[[@as string, string]]
      elseif cat == "extension" then
        return Icons.get_icon(nil, name, { default = false }) --[[@as string, string]]
      end
    end,
  }
  for _, fn in ipairs(try) do
    local ret = { pcall(fn) }
    if ret[1] and ret[2] then
      return ret[2], ret[3]
    end
  end
  return opts.fallback.file or "󰈔 "
end

-- Encodes a string to be used as a file name.
---@param str string
function M.file_encode(str)
  return str:gsub("([^%w%-_%.\t ])", function(c)
    return string.format("_%%%02X", string.byte(c))
  end)
end

-- Decodes a file name to a string.
---@param str string
function M.file_decode(str)
  return str:gsub("_%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end)
end

---@param fg string foreground color
---@param bg string background color
---@param alpha number number between 0 and 1. 0 results in bg, 1 results in fg
function M.blend(fg, bg, alpha)
  local bg_rgb = { tonumber(bg:sub(2, 3), 16), tonumber(bg:sub(4, 5), 16), tonumber(bg:sub(6, 7), 16) }
  local fg_rgb = { tonumber(fg:sub(2, 3), 16), tonumber(fg:sub(4, 5), 16), tonumber(fg:sub(6, 7), 16) }
  local blend = function(i)
    local ret = (alpha * fg_rgb[i] + ((1 - alpha) * bg_rgb[i]))
    return math.floor(math.min(math.max(0, ret), 255) + 0.5)
  end
  return string.format("#%02x%02x%02x", blend(1), blend(2), blend(3))
end

local transparent ---@type boolean?
--- Check if the colorscheme is transparent.
function M.is_transparent()
  if transparent == nil then
    transparent = M.color("Normal", "bg") == nil
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("snacks_util_transparent", { clear = true }),
      callback = function()
        transparent = nil
      end,
    })
  end
  return transparent
end

--- Redraw the range of lines in the window.
--- Optimized for Neovim >= 0.10
---@param win number
---@param from number -- 1-indexed, inclusive
---@param to number -- 1-indexed, inclusive
function M.redraw_range(win, from, to)
  if vim.api.nvim__redraw and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim__redraw({ win = win, range = { math.floor(from - 1), math.floor(to) }, valid = true, flush = false })
  else
    vim.cmd([[redraw!]])
  end
end

--- Redraw the window.
--- Optimized for Neovim >= 0.10
---@param win number
function M.redraw(win)
  if vim.api.nvim__redraw then
    vim.api.nvim__redraw({ win = win, valid = false, flush = false })
  else
    vim.cmd([[redraw!]])
  end
end

local mod_timer = assert(uv.new_timer())
local mod_cb = {} ---@type table<string, fun(modname:string)[]>

---@return boolean waiting
local function mod_check()
  for modname, cbs in pairs(mod_cb) do
    if package.loaded[modname] then
      mod_cb[modname] = nil
      for _, cb in ipairs(cbs) do
        cb(modname)
      end
    end
  end
  return next(mod_cb) ~= nil
end

--- Call a function when a module is loaded.
--- The callback is called immediately if the module is already loaded.
--- Otherwise, it is called when the module is loaded.
---@param modname string
---@param cb fun(modname:string)
function M.on_module(modname, cb)
  mod_cb[modname] = mod_cb[modname] or {}
  table.insert(mod_cb[modname], cb)
  if mod_check() then
    mod_timer:start(
      100,
      100,
      vim.schedule_wrap(function()
        return not mod_check() and mod_timer:stop()
      end)
    )
  end
end

---@param str string
function M.keycode(str)
  return vim.api.nvim_replace_termcodes(str, true, true, true)
end

--- Get a buffer or global variable.
---@generic T
---@param buf? number
---@param name string
---@param default? T
---@return T
function M.var(buf, name, default)
  local ok, ret = pcall(function()
    return vim.b[buf or 0][name]
  end)
  if ok and ret ~= nil then
    return ret
  end
  ret = vim.g[name]
  if ret ~= nil then
    return ret
  end
  return default
end

local keys = {} ---@type table<string, fun(key:string)[]>
local on_key_ns ---@type number?

---@param key string
---@param cb fun(key:string)
function M.on_key(key, cb)
  local code = M.keycode(key)
  keys[code] = keys[code] or {}
  table.insert(keys[code], cb)
  on_key_ns = on_key_ns
    or vim.on_key(function(resolved, typed)
      for _, c in ipairs(keys[typed or resolved] or {}) do
        pcall(c, typed)
      end
    end)
end

---@generic T
---@param t T
---@return { value?:T }|fun():T?
function M.ref(t)
  return setmetatable({ value = t }, {
    __mode = "v",
    __call = function(m)
      return m.value
    end,
  })
end

---@generic T
---@param fn T
---@param opts? {ms?:number}
---@return T
function M.throttle(fn, opts)
  local timer = assert(uv.new_timer())
  local trailing, ms = false, opts and opts.ms or 20
  local running = false
  local function run()
    running = true
    if vim.in_fast_event() then
      return vim.schedule(run)
    end
    fn()
    running = false
  end
  return function()
    if running or timer:is_active() then
      trailing = true
      return
    end
    trailing = false
    run()
    timer:start(ms, 0, function()
      return trailing and run()
    end)
  end
end

---@generic T
---@param fn T
---@param opts? {ms?:number}
---@return T
function M.debounce(fn, opts)
  local timer = assert(uv.new_timer())
  local ms = opts and opts.ms or 20
  return function()
    timer:start(ms, 0, vim.schedule_wrap(fn))
  end
end

---@param key string
function M.normkey(key)
  if key_cache[key] then
    return key_cache[key]
  end
  local function norm(v)
    local l = v:lower()
    if l == "leader" then
      return M.normkey("<leader>")
    elseif l == "localleader" then
      return M.normkey("<localleader>")
    end
    return vim.fn.keytrans(M.keycode(("<%s>"):format(v)))
  end
  local orig = key
  key = key:gsub("<lt>", "<")
  local lower = key:lower()
  if lower == "<leader>" then
    key = vim.g.mapleader
    key = vim.fn.keytrans((not key or key == "") and "\\" or key)
  elseif lower == "<localleader>" then
    key = vim.g.maplocalleader
    key = vim.fn.keytrans((not key or key == "") and "\\" or key)
  else
    local extracted = {} ---@type string[]
    local function extract(v)
      v = v:sub(2, -2)
      if v:sub(2, 2) == "-" and v:sub(1, 1):find("[aAmMcCsS]") then
        local m = v:sub(1, 1):upper()
        m = m == "A" and "M" or m
        local k = v:sub(3)
        if #k > 1 then
          return norm(v)
        end
        if m == "C" then
          k = k:upper()
        elseif m == "S" then
          return k:upper()
        end
        return ("<%s-%s>"):format(m, k)
      end
      return norm(v)
    end
    local placeholder = "_#_"
    ---@param v string
    key = key:gsub("(%b<>)", function(v)
      table.insert(extracted, extract(v))
      return placeholder
    end)
    key = vim.fn.keytrans(key):gsub("<lt>", "<")

    -- Restore extracted %b<> sequences
    local i = 0
    key = key:gsub(placeholder, function()
      i = i + 1
      return extracted[i] or ""
    end)
  end
  key_cache[orig] = key
  key_cache[key] = key
  return key
end

---@param win? number
function M.is_float(win)
  return vim.api.nvim_win_get_config(win or 0).relative ~= ""
end

function M.spinner()
  local spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
  return spinner[math.floor(uv.hrtime() / (1e6 * 80)) % #spinner + 1]
end

M.base64 = vim.base64 and vim.base64.encode
  or function(data)
    data = tostring(data)
    local bit = require("bit")
    local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local b64, len = "", #data
    for i = 1, len, 3 do
      local a, b, c = data:byte(i, i + 2)
      local buffer = bit.bor(bit.lshift(a, 16), bit.lshift(b or 0, 8), c or 0)
      for j = 0, 3 do
        local index = bit.rshift(buffer, (3 - j) * 6) % 64
        b64 = b64 .. b64chars:sub(index + 1, index + 1)
      end
    end
    local padding = (3 - len % 3) % 3
    b64 = b64:sub(1, -1 - padding) .. ("="):rep(padding)
    return b64
  end

--- Parse async when available.
---@param parser vim.treesitter.LanguageTree
---@param range boolean|Range|nil: Parse this range in the parser's source.
---@param on_parse fun(err?: string, trees?: table<integer, TSTree>) Function invoked when parsing completes.
function M.parse(parser, range, on_parse)
  ---@diagnostic disable-next-line: invisible
  local have_async = vim.fn.has("nvim-0.11.4") == 1 or (vim.treesitter.languagetree or {})._async_parse ~= nil
  if have_async then
    parser:parse(range, on_parse)
  else
    parser:parse(range)
    on_parse(nil, parser:trees())
  end
end

---@param handle? uv.uv_handle_t|uv.uv_timer_t
function M.stop(handle)
  if handle and not handle:is_closing() then
    if handle.stop then
      handle:stop()
    end
    handle:close()
  end
end

--- Better validation to check if path is a dir or a file
---@param path string
---@return "directory"|"file"
function M.path_type(path)
  local stat = uv.fs_stat(path)
  if stat and stat.type then
    return stat.type
  end
  if vim.fn.isdirectory(path) == 1 then
    return "directory"
  end
  return "file"
end

return M
