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

local defaults ---@type snacks.picker.Config?

--- Fixes keys before merging configs for correctly resolving keymaps.
--- For example: <c-s> -> <C-S>
---@param opts? snacks.picker.Config
function M.fix_keys(opts)
  opts = opts or {}
  -- fix keys in sources
  for _, source in pairs(opts.sources or {}) do
    M.fix_keys(source)
  end
  if not opts.win then
    return opts
  end
  -- fix keys in wins
  for _, win in pairs(opts.win) do
    ---@cast win snacks.win.Config
    if win.keys then
      local keys = vim.tbl_keys(win.keys) ---@type string[]
      for _, key in ipairs(keys) do
        local norm = Snacks.util.normkey(key)
        if key ~= norm then
          win.keys[norm], win.keys[key] = win.keys[key], nil
        end
      end
    end
  end
  return opts
end

---@param opts? snacks.picker.Config
function M.get(opts)
  M.setup()
  opts = M.fix_keys(opts)

  -- Setup defaults
  if not defaults then
    defaults = require("snacks.picker.config.defaults").defaults
    defaults.sources = require("snacks.picker.config.sources")
    defaults.layouts = require("snacks.picker.config.layouts")
    M.fix_keys(defaults)
  end

  local user = M.fix_keys(Snacks.config.picker or {})
  opts.source = M.alias[opts.source] or opts.source

  -- Prepare config
  local global = Snacks.config.get("picker", defaults, opts) -- defaults + global user config
  local source = opts.source and global.sources[opts.source] or {}
  ---@type snacks.picker.Config[]
  local todo = {
    vim.deepcopy(defaults),
    vim.deepcopy(user),
    vim.deepcopy(source),
    opts,
  }

  -- Merge the confirm action into the actions table
  for _, t in ipairs(todo) do
    if t.confirm then
      t.actions = t.actions or {}
      t.actions.confirm = t.confirm
    end
  end

  -- Merge the configs
  opts = Snacks.config.merge(unpack(todo))
  if opts.cwd == true or opts.cwd == "" then
    opts.cwd = nil
  elseif opts.cwd then
    opts.cwd = svim.fs.normalize(vim.fn.fnamemodify(opts.cwd, ":p"))
  end
  for _, t in ipairs(todo) do
    if t.config then
      opts = t.config(opts) or opts
    end
  end

  -- add hl groups and actions for toggles
  opts.actions = opts.actions or {}
  for name in pairs(opts.toggles) do
    local hl = table.concat(vim.tbl_map(function(a)
      return a:sub(1, 1):upper() .. a:sub(2)
    end, vim.split(name, "_")))
    Snacks.util.set_hl({ [hl] = "SnacksPickerToggle" }, { default = true, prefix = "SnacksPickerToggle" })
    opts.actions["toggle_" .. name] = function(picker)
      picker.opts[name] = not picker.opts[name]
      picker.list:set_target()
      picker:find()
    end
  end

  M.fix_old(opts)

  M.multi(opts)
  return opts
end

--- Fixes old config options
---@param opts snacks.picker.Config
function M.fix_old(opts)
  if opts.previewers.diff.native ~= nil then
    opts.previewers.diff.builtin = not opts.previewers.diff.native
  end
  if opts.previewers.git.native ~= nil then
    opts.previewers.git.builtin = not opts.previewers.git.native
  end
end

---@param opts snacks.picker.Config
function M.multi(opts)
  if not opts.multi then
    return opts
  end
  local Finder = require("snacks.picker.core.finder")

  local finders = {} ---@type snacks.picker.finder[]
  local formats = {} ---@type snacks.picker.format[]
  local previews = {} ---@type snacks.picker.preview[]
  local confirms = {} ---@type snacks.picker.Action.spec[]

  local sources = {} ---@type snacks.picker.Config[]
  for _, source in ipairs(opts.multi) do
    if type(source) == "string" then
      source = { source = source }
    end
    ---@cast source snacks.picker.Config
    source = Snacks.config.merge({}, opts.sources[source.source], source) --[[@as snacks.picker.Config]]
    source.actions = source.actions or {}
    if source.confirm then
      source.actions.confirm = source.confirm
    end
    local finder = M.finder(source.finder)
    finders[#finders + 1] = function(fopts, ctx)
      fopts = Snacks.config.merge({}, vim.deepcopy(source), fopts)
      -- Update source filter when needed
      if not vim.tbl_isempty(fopts.filter or {}) then
        ctx = setmetatable({}, { __index = ctx })
        ctx.filter = ctx.filter:clone():init(fopts)
      end
      return finder(fopts, ctx)
    end
    confirms[#confirms + 1] = source.actions.confirm or "jump"
    previews[#previews + 1] = M.preview(source)
    formats[#formats + 1] = M.format(source)
    sources[#sources + 1] = source

    -- merge keys
    for w, win in pairs(source.win or {}) do
      if win.keys then
        opts.win = opts.win or {}
        opts.win[w] = opts.win[w] or {}
        opts.win[w].keys = Snacks.config.merge(opts.win[w].keys or {}, win.keys)
      end
    end
  end

  opts.finder = opts.finder or Finder.multi(finders)
  opts.format = opts.format or function(item, picker)
    return formats[item.source_id](item, picker)
  end
  opts.preview = opts.preview or function(ctx)
    return previews[ctx.item.source_id](ctx)
  end
  opts.confirm = opts.confirm
    or function(picker, item, action)
      return confirms[item.source_id](picker, item, action)
    end
end

---@param opts snacks.picker.Config
function M.format(opts)
  local ret = type(opts.format) == "string" and (Snacks.picker.format[opts.format] or M.field(opts.format))
    or opts.format
    or Snacks.picker.format.file
  ---@cast ret snacks.picker.format
  return ret
end

---@param opts snacks.picker.Config
function M.transform(opts)
  local ret = type(opts.transform) == "string" and require("snacks.picker.transform")[opts.transform]
    or opts.transform
    or nil
  ---@cast ret snacks.picker.transform?
  return ret
end

---@param opts snacks.picker.Config
function M.preview(opts)
  local preview = opts.preview or Snacks.picker.preview.file
  preview = type(preview) == "string" and (Snacks.picker.preview[preview] or M.field(preview)) or preview
  ---@cast preview snacks.picker.preview
  return preview
end

---@param opts snacks.picker.Config
function M.sort(opts)
  local sort = opts.sort or require("snacks.picker.sort").default()
  sort = type(sort) == "table" and require("snacks.picker.sort").default(sort) or sort
  ---@cast sort snacks.picker.sort
  return sort
end

--- Resolve the layout configuration
---@param opts snacks.picker.Config|string
function M.layout(opts)
  if type(opts) == "string" then
    opts = M.get({ layout = { preset = opts } })
  end

  -- Resolve the layout configuration
  local layout = M.resolve(opts.layout or {}, opts.source)
  layout = type(layout) == "string" and { preset = layout } or layout
  ---@cast layout snacks.picker.layout.Config

  -- only resolve presets when the layout has no layout
  if not (layout.layout and layout.layout[1]) then
    -- Resolve the preset
    local layouts = opts.layouts or M.get().layouts or {}
    local done = {} ---@type table<string, boolean>
    local todo = { layout } ---@type snacks.picker.layout.Config[]
    while true do
      local preset = M.resolve(todo[1].preset or "custom", opts.source)
      if not preset or done[preset] or not layouts[preset] then
        break
      end
      done[preset] = true
      table.insert(todo, 1, vim.deepcopy(layouts[preset]))
    end

    -- Merge and return the layout
    layout = Snacks.config.merge(unpack(todo)) --[[@as snacks.picker.layout.Config]]
  end

  -- Fix deprecated layout options
  layout.hidden = layout.hidden or {}
  if layout.preview == false then
    table.insert(layout.hidden, "preview")
    layout.preview = nil
  elseif type(layout.preview) == "table" then
    ---@cast layout snacks.picker.layout.Config|{preview: {enabled: boolean, main: boolean}}
    if layout.preview.enabled == false then
      table.insert(layout.hidden, "preview")
    end
    if layout.preview.main then
      layout.preview = "main"
    else
      layout.preview = nil
    end
  end

  if layout.config then
    layout = layout.config(layout) or layout
  end

  return layout
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
  return M.field(finder) or nop
end

--- Resolves a module field
---@param spec string
function M.field(spec)
  local parts = vim.split(spec, ".", { plain = true })
  local name, field = parts[#parts]:match("^(.-)[_#](.+)$")
  if name and field then
    parts[#parts] = name
  else
    field = parts[#parts]
  end
  local ok, ret = pcall(function()
    return require("snacks.picker.source." .. table.concat(parts, "."))[field]
  end)
  return ok and ret or nil
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
  if rawget(Snacks.picker, source) then
    return Snacks.picker[source]
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
