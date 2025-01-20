---@class snacks.util
local M = {}

M.meta = {
  desc = "Utility functions for Snacks _(library)_",
}

local uv = vim.uv or vim.loop
local key_cache = {} ---@type table<string, string>

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

---@param group string hl group to get color from
---@param prop? string property to get. Defaults to "fg"
function M.color(group, prop)
  prop = prop or "fg"
  local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
  return hl[prop] and string.format("#%06x", hl[prop])
end

--- Set window-local options.
---@param win number
---@param wo vim.wo|{}
function M.wo(win, wo)
  for k, v in pairs(wo or {}) do
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

--- Get an icon from `mini.icons` or `nvim-web-devicons`.
---@param name string
---@param cat? string defaults to "file"
---@return string, string?
function M.icon(name, cat)
  local try = {
    function()
      return require("mini.icons").get(cat or "file", name)
    end,
    function()
      if cat == "directory" then
        return " ", "Directory"
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
  return " "
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
  if vim.api.nvim__redraw then
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
  local timer, trailing, ms = assert(uv.new_timer()), false, opts and opts.ms or 20
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

---@param key string
function M.normkey(key)
  if key_cache[key] then
    return key_cache[key]
  end
  local k = key
  key = key:gsub("<[aAmMcC]%-.>", string.lower)
  if not key:match("^<[aAmMcC]%-.>$") then
    key = vim.fn.keytrans(M.keycode(key))
  end
  key_cache[k] = key
  key_cache[key] = key
  return key
end

return M
