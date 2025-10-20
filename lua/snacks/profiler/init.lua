require("snacks")

-- ### Traces
--
---@class snacks.profiler.Trace
---@field name string fully qualified name of the function
---@field time number time in nanoseconds
---@field depth number stack depth
---@field [number] snacks.profiler.Trace child traces
---@field fname string function name
---@field fn function function reference
---@field modname? string module name
---@field require? string special case for require
---@field autocmd? string special case for autocmd
---@field count? number number of calls
---@field def? snacks.profiler.Loc location of the definition
---@field ref? snacks.profiler.Loc location of the reference (caller)
---@field loc? snacks.profiler.Loc normalized location

---@class snacks.profiler.Loc
---@field file string path to the file
---@field line number line number
---@field loc? string normalized location
---@field modname? string module name
---@field plugin? string plugin name

-- ### Pick: grouping, filtering and sorting
--
---@class snacks.profiler.Find
---@field structure? boolean show traces as a tree or flat list
---@field sort? "time"|"count"|false sort by time or count, or keep original order
---@field loc? "def"|"ref" what location to show in the preview
---@field group? boolean|snacks.profiler.Field group traces by field
---@field filter? snacks.profiler.Filter filter traces by field(s)
---@field min_time? number only show grouped traces with `time >= min_time`

---@class snacks.profiler.Pick: snacks.profiler.Find
---@field picker? snacks.profiler.Picker

---@alias snacks.profiler.Picker "snacks"|"trouble"
---@alias snacks.profiler.Pick.spec snacks.profiler.Pick|{preset?:string}|fun():snacks.profiler.Pick

---@alias snacks.profiler.Field
---| "name" fully qualified name of the function
---| "def" definition
---| "ref" reference (caller)
---| "require" require
---| "autocmd" autocmd
---| "modname" module name of the called function
---| "def_file" file of the definition
---| "def_modname" module name of the definition
---| "def_plugin" plugin that defines the function
---| "ref_file" file of the reference
---| "ref_modname" module name of the reference
---| "ref_plugin" plugin that references the function

---@class snacks.profiler.Filter
---@field name? string|boolean fully qualified name of the function
---@field def? string|boolean location of the definition
---@field ref? string|boolean location of the reference (caller)
---@field require? string|boolean special case for require
---@field autocmd? string|boolean special case for autocmd
---@field modname? string|boolean module name
---@field def_file? string|boolean file of the definition
---@field def_modname? string|boolean module name of the definition
---@field def_plugin? string|boolean plugin that defines the function
---@field ref_file? string|boolean file of the reference
---@field ref_modname? string|boolean module name of the reference
---@field ref_plugin? string|boolean plugin that references the function

-- ### UI
--
---@alias snacks.profiler.Badge {icon:string, text:string, padding?:boolean, level?:string}
---@alias snacks.profiler.Badge.type "time"|"pct"|"count"|"name"|"trace"

---@class snacks.profiler.Highlights
---@field min_time? number only highlight entries with time >= min_time
---@field max_shade? number -- time in ms for the darkest shade
---@field badges? snacks.profiler.Badge.type[] badges to show
---@field align? "right"|"left"|number align the badges right, left or at a specific column

-- ### Other
--
---@class snacks.profiler.Startup
---@field event? string
---@field pattern? string|string[] pattern to match for the autocmd

---@alias snacks.profiler.GroupFn fun(entry:snacks.profiler.Trace):{key:string, name?:string}?

---@class snacks.profiler
---@field core snacks.profiler.core
---@field loc snacks.profiler.loc
---@field tracer snacks.profiler.tracer
---@field ui snacks.profiler.ui
---@field picker snacks.profiler.picker
local M = {}

M.meta = {
  desc = "Neovim lua profiler",
}

local mods = { core = true, loc = true, tracer = true, ui = true, picker = true }
setmetatable(M, {
  __index = function(t, k)
    if mods[k] then
      ---@diagnostic disable-next-line: no-unknown
      t[k] = require("snacks.profiler." .. k)
    end
    return rawget(t, k)
  end,
})

---@class snacks.profiler.Config
local defaults = {
  autocmds = true,
  runtime = vim.env.VIMRUNTIME, ---@type string
  -- thresholds for buttons to be shown as info, warn or error
  -- value is a tuple of [warn, error]
  thresholds = {
    time = { 2, 10 },
    pct = { 10, 20 },
    count = { 10, 100 },
  },
  on_stop = {
    highlights = true, -- highlight entries after stopping the profiler
    pick = true, -- show a picker after stopping the profiler (uses the `on_stop` preset)
  },
  ---@type snacks.profiler.Highlights
  highlights = {
    min_time = 0, -- only highlight entries with time > min_time (in ms)
    max_shade = 20, -- time in ms for the darkest shade
    badges = { "time", "pct", "count", "trace" },
    align = 80,
  },
  pick = {
    picker = "snacks", ---@type snacks.profiler.Picker
    ---@type snacks.profiler.Badge.type[]
    badges = { "time", "count", "name" },
    ---@type snacks.profiler.Highlights
    preview = {
      badges = { "time", "pct", "count" },
      align = "right",
    },
  },
  startup = {
    event = "VimEnter", -- stop profiler on this event. Defaults to `VimEnter`
    after = true, -- stop the profiler **after** the event. When false it stops **at** the event
    pattern = nil, -- pattern to match for the autocmd
    pick = true, -- show a picker after starting the profiler (uses the `startup` preset)
  },
  ---@type table<string, snacks.profiler.Pick|fun():snacks.profiler.Pick?>
  presets = {
    startup = { min_time = 1, sort = false },
    on_stop = {},
    filter_by_plugin = function()
      return { filter = { def_plugin = vim.fn.input("Filter by plugin: ") } }
    end,
  },
  ---@type string[]
  globals = {
    -- "vim",
    -- "vim.api",
    -- "vim.keymap",
    -- "Snacks.dashboard.Dashboard",
  },
  -- filter modules by pattern.
  -- longest patterns are matched first
  filter_mod = {
    default = true, -- default value for unmatched patterns
    ["^vim%."] = false,
    ["mason-core.functional"] = false,
    ["mason-core.functional.data"] = false,
    ["mason-core.optional"] = false,
    ["which-key.state"] = false,
  },
  filter_fn = {
    default = true,
    ["^.*%._[^%.]*$"] = false,
    ["trouble.filter.is"] = false,
    ["trouble.item.__index"] = false,
    ["which-key.node.__index"] = false,
    ["smear_cursor.draw.wo"] = false,
    ["^ibl%.utils%."] = false,
  },
  -- stylua: ignore
  icons = {
    time    = " ",
    pct     = " ",
    count   = " ",
    require = "󰋺 ",
    modname = "󰆼 ",
    plugin  = " ",
    autocmd = "⚡",
    file    = " ",
    fn      = "󰊕 ",
    status  = "󰈸 ",
  },
  debug = false,
}

M.config = Snacks.config.get("profiler", defaults)

local attached_debug = false
local loaded = false

-- Toggle the profiler
function M.toggle()
  if M.core.running then
    M.stop()
  else
    M.start()
  end
  return M.core.running
end

-- Statusline component
function M.status()
  return {
    function()
      return ("%s %d events"):format(M.config.icons.status, #M.core.events)
    end,
    color = "DiagnosticError",
    cond = function()
      return M.core.running
    end,
  }
end

-- Start the profiler
---@param opts? snacks.profiler.Config
function M.start(opts)
  if M.core.running then
    return Snacks.notify.warn("Profiler is already enabled")
  end
  M.config = Snacks.config.get("profiler", defaults, opts)

  M.highlight(false)
  M.core.start(M.config)
end

local function load()
  if loaded then
    return
  end
  loaded = true
  M.tracer.load() -- load traces
  M.loc.load() -- add and normalize locations
  M.ui.load() -- load highlights
  vim.api.nvim_exec_autocmds("User", { pattern = "SnacksProfilerLoaded", modeline = false })
end

-- Stop the profiler
---@param opts? {highlights?:boolean, pick?:snacks.profiler.Pick.spec}
function M.stop(opts)
  if not M.core.running then
    return Snacks.notify.warn("Profiler is not enabled")
  end
  M.core.stop()
  opts = vim.tbl_extend("force", {}, M.config.on_stop, opts or {})
  if opts.pick == true then
    opts.pick = M.config.presets.on_stop or {}
  elseif opts.pick == false then
    opts.pick = nil
  end
  loaded = false
  vim.schedule(function()
    load()
    if opts.highlights then
      M.highlight(true)
    end
    if opts.pick then
      M.pick(opts.pick)
    end
  end)
end

-- Check if the profiler is running
function M.running()
  return M.core.running
end

-- Profile the profiler
---@private
function M.debug()
  if not M.core.running then
    return Snacks.notify.warn("Profiler is not enabled")
  end
  if loaded then
    return Snacks.notify.warn("Profiler is already loaded")
  end
  if not attached_debug then
    attached_debug = true
    M.core.skip(M.core.caller)
    M.core.skip(M.core.trace)
    M.core.skip(M.loc.loc)
    M.core.skip(M.loc.norm)
    M.core.skip(M.loc.realpath)
    M.core.attach_mod("vim.fs", vim.fs, { force = true })
    M.core.attach_mod("snacks.profiler", M, { force = true })
    for mod in pairs(mods) do
      M.core.attach_mod("snacks.profiler." .. mod, M[mod], { force = true })
    end
  end
  local event_count = #M.core.events
  local me = M.core.me
  M.core.me = "__ignore__"
  load()
  M.pick({ picker = "foo", group = "name", structure = true })
  M.core.events = vim.list_slice(M.core.events, event_count)
  loaded = false
  M.stop()
  M.core.me = me
end

-- Group and filter traces
---@param opts snacks.profiler.Find
function M.find(opts)
  load()
  return M.tracer.find(opts)
end

-- Group and filter traces and open a picker
---@param opts? snacks.profiler.Pick.spec
function M.pick(opts)
  load()
  if type(opts) == "function" then
    opts = opts()
    if not opts then
      return
    end
  end
  opts = opts or {}
  if opts.preset then
    local preset = M.config.presets[opts.preset]
    preset = type(preset) == "function" and preset()
    if not preset then
      return
    end
    opts = vim.tbl_deep_extend("force", {}, preset, opts)
  end
  ---@cast opts snacks.profiler.Pick
  return M.picker.open(opts)
end

--- Open a scratch buffer with the profiler picker options
function M.scratch()
  return Snacks.scratch({
    ft = "lua",
    icon = " ",
    name = "Profiler Picker Options",
    template = ("---@module 'snacks'\n\nSnacks.profiler.pick(%s)"):format(vim.inspect({
      structure = true,
      group = "name",
      sort = "time",
      min_time = 1,
    })),
  })
end

-- Start the profiler on startup, and stop it after the event has been triggered.
---@param opts snacks.profiler.Config
function M.startup(opts)
  M.config = Snacks.config.get("profiler", defaults, opts)
  local event, pattern = M.config.startup.event or "VimEnter", M.config.startup.pattern
  if event == "VeryLazy" then
    event, pattern = "User", event
  end
  local cb = function()
    local pick = M.config.startup.pick and M.config.presets.startup
    Snacks.profiler.stop({ pick = pick })
  end
  if M.config.startup.after then
    cb = vim.schedule_wrap(cb)
  end
  vim.api.nvim_create_autocmd(event, { pattern = pattern, once = true, callback = cb })
  M.start(opts)
end

-- Toggle the profiler highlights
---@param enable? boolean
function M.highlight(enable)
  if enable == nil then
    enable = not M.ui.enabled
  end
  if enable == M.ui.enabled then
    return
  end
  if enable then
    load()
    M.ui.show()
  else
    M.ui.hide()
  end
end

return M
