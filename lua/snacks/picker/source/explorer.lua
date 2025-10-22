---@diagnostic disable: await-in-sync
local Actions = require("snacks.explorer.actions")
local Tree = require("snacks.explorer.tree")

local M = {}

---@type table<snacks.Picker, snacks.picker.explorer.State>
M._state = setmetatable({}, { __mode = "k" })
local uv = vim.uv or vim.loop

---@class snacks.picker.explorer.Item: snacks.picker.finder.Item
---@field file string
---@field dir? boolean
---@field parent? snacks.picker.explorer.Item
---@field open? boolean
---@field last? boolean
---@field sort? string
---@field internal? boolean internal parent directories not part of fd output
---@field status? string

local function norm(path)
  return svim.fs.normalize(path)
end

---@class snacks.picker.explorer.State
---@field on_find? fun()?
local State = {}
State.__index = State
---@param picker snacks.Picker
function State.new(picker)
  local self = setmetatable({}, State)

  local opts = picker.opts --[[@as snacks.picker.explorer.Config]]
  local r = picker:ref()
  local function ref()
    local v = r.value
    return v and not v.closed and v or nil
  end

  Tree:refresh(picker:cwd())

  local buf = vim.api.nvim_win_get_buf(picker.main)
  local buf_file = svim.fs.normalize(vim.api.nvim_buf_get_name(buf))
  if uv.fs_stat(buf_file) then
    Tree:open(buf_file)
  end

  if opts.watch then
    local on_close = picker.opts.on_close
    picker.opts.on_close = function(p)
      require("snacks.explorer.watch").abort()
      if on_close then
        on_close(p)
      end
    end
  end

  picker.list.win:on("BufWritePost", function(_, ev)
    local p = ref()
    if p then
      Tree:refresh(ev.file)
      Actions.update(p)
    end
  end)

  picker.list.win:on("WinEnter", function(_, ev)
    local p = ref()
    if p then
      p._main:update()
    end
  end)

  picker.list.win:on("DirChanged", function(_, ev)
    local p = ref()
    if p then
      p:set_cwd(svim.fs.normalize(ev.file))
      p:find()
    end
  end)

  if opts.diagnostics then
    local dirty = false
    local diag_update = Snacks.util.debounce(function()
      dirty = false
      local p = ref()
      if p then
        if require("snacks.explorer.diagnostics").update(p:cwd()) then
          p.list:set_target()
          p:find()
        end
      end
    end, { ms = 200 })
    picker.list.win:on({ "InsertLeave", "DiagnosticChanged" }, function(_, ev)
      dirty = dirty or ev.event == "DiagnosticChanged"
      if vim.fn.mode() == "n" and dirty then
        diag_update()
      end
    end)
  end

  -- schedule initial follow
  if opts.follow_file then
    picker.list.win:on({ "WinEnter", "BufEnter" }, function(_, ev)
      vim.schedule(function()
        if ev.buf ~= vim.api.nvim_get_current_buf() then
          return
        end
        local p = ref()
        if not p or p:is_focused() or not p:on_current_tab() or p.closed then
          return
        end
        local win = vim.api.nvim_get_current_win()
        if vim.api.nvim_win_get_config(win).relative ~= "" then
          return
        end
        local file = vim.api.nvim_buf_get_name(ev.buf)
        local item = p:current()
        if item and item.file == norm(file) then
          return
        end
        Actions.update(p, { target = file })
      end)
    end)
    self.on_find = function()
      local p = ref()
      if p and buf_file then
        Actions.update(p, { target = buf_file })
      end
    end
  end
  return self
end

---@param ctx snacks.picker.finder.ctx
function State:setup(ctx)
  local opts = ctx.picker.opts --[[@as snacks.picker.explorer.Config]]
  if opts.watch then
    require("snacks.explorer.watch").watch(ctx.filter.cwd)
  end
  return not ctx.filter:is_empty()
end

---@param opts snacks.picker.explorer.Config
function M.setup(opts)
  local searching = false
  return Snacks.config.merge(opts, {
    actions = {
      confirm = Actions.actions.confirm,
    },
    filter = {
      --- Trigger finder when pattern toggles between empty / non-empty
      ---@param picker snacks.Picker
      ---@param filter snacks.picker.Filter
      transform = function(picker, filter)
        local s = not filter:is_empty()
        if searching ~= s then
          searching = s
          filter.meta.searching = searching
          return true
        end
      end,
    },
    formatters = {
      file = {
        filename_only = opts.tree,
      },
    },
  })
end

---@param picker snacks.Picker
function M.get_state(picker)
  if not M._state[picker] then
    M._state[picker] = State.new(picker)
  end
  return M._state[picker]
end

---@param opts snacks.picker.explorer.Config
---@type snacks.picker.finder
function M.explorer(opts, ctx)
  local state = M.get_state(ctx.picker)

  ctx.picker.matcher.opts.keep_parents = false
  if state:setup(ctx) then
    ctx.picker.matcher.opts.keep_parents = true
    return M.search(opts, ctx)
  end

  if opts.git_status then
    require("snacks.explorer.git").update(ctx.filter.cwd, {
      untracked = opts.git_untracked,
      on_update = function()
        if ctx.picker.closed then
          return
        end
        ctx.picker.list:set_target()
        ctx.picker:find()
      end,
    })
  end

  if opts.diagnostics then
    require("snacks.explorer.diagnostics").update(ctx.filter.cwd)
  end

  return function(cb)
    if state.on_find then
      ctx.picker.matcher.task:on("done", vim.schedule_wrap(state.on_find))
      state.on_find = nil
    end
    local items = {} ---@type table<string, snacks.picker.explorer.Item>
    local top = Tree:find(ctx.filter.cwd)
    local last = {} ---@type table<snacks.picker.explorer.Node, snacks.picker.explorer.Item>
    Tree:get(ctx.filter.cwd, function(node)
      local parent = node.parent and items[node.parent.path] or nil
      local status = node.status
      if not status and parent and parent.dir_status then
        status = parent.dir_status
      end
      local item = {
        file = node.path,
        dir = node.dir,
        open = node.open,
        dir_status = node.dir_status or parent and parent.dir_status,
        text = node.path,
        parent = parent,
        hidden = node.hidden,
        ignored = node.ignored,
        status = (not node.dir or not node.open or opts.git_status_open) and status or nil,
        last = true,
        type = node.type,
        severity = (not node.dir or not node.open or opts.diagnostics_open) and node.severity or nil,
      }
      if last[node.parent] then
        last[node.parent].last = false
      end
      last[node.parent] = item
      if top == node then
        item.hidden = false
        item.ignored = false
      end
      items[node.path] = item
      cb(item)
    end, { hidden = opts.hidden, ignored = opts.ignored, exclude = opts.exclude, include = opts.include })
  end
end

---@param opts snacks.picker.explorer.Config
---@type snacks.picker.finder
function M.search(opts, ctx)
  opts = Snacks.picker.util.shallow_copy(opts)
  opts.cmd = "fd"
  opts.cwd = ctx.filter.cwd
  opts.notify = false
  opts.args = {
    "--type",
    "d", -- include directories
    "--path-separator", -- same everywhere
    "/",
  }
  opts.dirs = { ctx.filter.cwd }
  ctx.picker.list:set_target()

  ---@type snacks.picker.explorer.Item
  local root = {
    file = opts.cwd,
    dir = true,
    open = true,
    text = "",
    sort = "",
    internal = true,
  }

  local files = require("snacks.picker.source.files").files(opts, ctx)

  local dirs = {} ---@type table<string, snacks.picker.explorer.Item>
  local last = {} ---@type table<snacks.picker.finder.Item, snacks.picker.finder.Item>

  ---@async
  return function(cb)
    cb(root)

    ---@param item snacks.picker.explorer.Item
    local function add(item)
      local dirname, basename = item.file:match("(.*)/(.*)")
      dirname, basename = dirname or "", basename or item.file
      local parent = dirs[dirname] ~= item and dirs[dirname] or root

      -- hierarchical sorting
      if item.dir then
        item.sort = parent.sort .. "!" .. basename .. " "
      else
        item.sort = parent.sort .. "#" .. basename .. " "
      end
      item.hidden = basename:sub(1, 1) == "."
      item.text = item.text:sub(1, #opts.cwd) == opts.cwd and item.text:sub(#opts.cwd + 2) or item.text
      local node = Tree:node(item.file)
      if node then
        item.dir = node.dir
        item.type = node.type
        item.status = (not node.dir or opts.git_status_open) and node.status or nil
      end

      if opts.tree then
        -- tree
        item.parent = parent
        if not last[parent] or last[parent].sort < item.sort then
          if last[parent] then
            last[parent].last = false
          end
          item.last = true
          last[parent] = item
        end
      end
      -- add to picker
      cb(item)
    end

    -- get files and directories
    files(function(item)
      ---@cast item snacks.picker.explorer.Item
      item.cwd = nil -- we use absolute paths

      -- Directories
      if item.file:sub(-1) == "/" then
        item.dir = true
        item.file = item.file:sub(1, -2)
        if dirs[item.file] then
          dirs[item.file].internal = false
          return
        end
        item.open = true
        dirs[item.file] = item
      end

      -- Add parents when needed
      for dir in Snacks.picker.util.parents(item.file, opts.cwd) do
        if dirs[dir] then
          break
        else
          dirs[dir] = {
            text = dir,
            file = dir,
            dir = true,
            open = true,
            internal = true,
          }
          add(dirs[dir])
        end
      end

      add(item)
    end)
  end
end

return M
