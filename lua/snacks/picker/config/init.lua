---@class snacks.picker.config
local M = {}

--- Source aliases
M.alias = {
  live_grep = "grep",
  find_files = "files",
  git_commits = "git_log",
  git_bcommits = "git_log_file",
  oldfiles = "recent",
}

---@param opts? snacks.picker.Config
function M.get(opts)
  M.setup()
  opts = opts or {}

  local sources = require("snacks.picker.config.sources")
  local defaults = require("snacks.picker.config.defaults").defaults
  defaults.sources = sources
  local user = Snacks.config.picker or {}
  opts.source = M.alias[opts.source] or opts.source

  local global = Snacks.config.get("picker", defaults, opts) -- defaults + global user config
  ---@type snacks.picker.Config[]
  local todo = {
    defaults,
    user,
    opts.source and global.sources[opts.source] or {},
    opts,
  }

  for _, t in ipairs(todo) do
    if t.confirm then
      t.actions = t.actions or {}
      t.actions.confirm = t.confirm
    end
  end

  local ret = vim.tbl_deep_extend("force", unpack(todo))
  ret.layouts = ret.layouts or {}
  local layouts = require("snacks.picker.config.layouts")
  for k, v in pairs(layouts or {}) do
    ret.layouts[k] = ret.layouts[k] or v
  end
  return ret
end

--- Resolve the layout configuration
---@param opts snacks.picker.Config|string
function M.layout(opts)
  if type(opts) == "string" then
    opts = M.get({ layout = { preset = opts } })
  end
  local layouts = require("snacks.picker.config.layouts")
  local layout = M.resolve(opts.layout or {}, opts.source)
  layout = type(layout) == "string" and { preset = layout } or layout
  ---@cast layout snacks.picker.layout.Config
  if layout.layout and layout.layout[1] then
    return layout
  end
  local preset = M.resolve(layout.preset or "custom", opts.source)
  local ret = vim.deepcopy(opts.layouts and opts.layouts[preset] or layouts[preset] or {})
  ret = vim.tbl_deep_extend("force", ret, layout or {})
  ret.preset = nil
  return ret
end

---@generic T
---@generic A
---@param v (fun(...:A):T)|unknown
---@param ... A
---@return T
function M.resolve(v, ...)
  return type(v) == "function" and v(...) or v
end

--- Get the finder
---@param finder string|snacks.picker.finder|snacks.picker.finder.multi
---@return snacks.picker.finder
function M.finder(finder)
  local nop = function()
    Snacks.notify.error("Finder not found:\n```lua\n" .. vim.inspect(finder) .. "\n```", { title = "Snacks Picker" })
  end
  if not finder or type(finder) == "function" then
    return finder
  end
  if type(finder) == "table" then
    ---@cast finder snacks.picker.finder.multi
    ---@type snacks.picker.finder[]
    local finders = vim.tbl_map(function(f)
      return M.finder(f)
    end, finder)
    return require("snacks.picker.core.finder").multi(finders)
  end
  ---@cast finder string
  local mod, fn = finder:match("^(.-)_(.+)$")
  if not (mod and fn) then
    mod, fn = finder, finder
  end
  local ok, ret = pcall(function()
    return require("snacks.picker.source." .. mod)[fn]
  end)
  return ok and ret or nop
end

local did_setup = false
function M.setup()
  if did_setup then
    return
  end
  did_setup = true
  require("snacks.picker.config.highlights")
  for source in pairs(Snacks.picker.config.get().sources) do
    M.wrap(source)
  end
  --- Automatically wrap new sources added after setup
  setmetatable(require("snacks.picker.config.sources"), {
    __newindex = function(t, k, v)
      rawset(t, k, v)
      M.wrap(k)
    end,
  })
end

---@param source string
---@param opts? {check?: boolean}
function M.wrap(source, opts)
  if opts and opts.check then
    local config = M.get()
    if not config.sources[source] then
      return
    end
  end
  ---@type fun(opts: snacks.picker.Config): snacks.Picker
  local ret = function(_opts)
    return Snacks.picker.pick(source, _opts)
  end
  ---@diagnostic disable-next-line: no-unknown
  Snacks.picker[source] = ret
  return ret
end

return M
