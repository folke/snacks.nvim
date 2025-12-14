local Async = require("snacks.picker.util.async")
local Finder = require("snacks.picker.core.finder")

local uv = vim.uv or vim.loop
Async.BUDGET = 10
local _id = 0

---@alias snacks.Picker.ref (fun():snacks.Picker?)|{value?: snacks.Picker}

---@class snacks.Picker
---@field id number
---@field opts snacks.picker.Config
---@field init_opts? snacks.picker.Config
---@field finder snacks.picker.Finder
---@field format snacks.picker.format
---@field input snacks.picker.input
---@field layout snacks.layout
---@field resolved_layout snacks.picker.layout.Config
---@field list snacks.picker.list
---@field matcher snacks.picker.Matcher
---@field main number
---@field _main snacks.picker.Main
---@field preview snacks.picker.Preview
---@field shown? boolean
---@field sort snacks.picker.sort
---@field updater uv.uv_timer_t
---@field start_time number
---@field title string
---@field closed? boolean
---@field history snacks.picker.History
---@field visual? snacks.picker.Visual
local M = {}

--- Keep track of garbage collection
---@type table<snacks.Picker,boolean>
M._pickers = setmetatable({}, { __mode = "k" })
--- These are active, so don't garbage collect them
---@type table<snacks.Picker,boolean>
M._active = {}

---@alias snacks.picker.history.Record {pattern: string, search: string, live?: boolean}

function M:__index(key)
  if M[key] then
    return M[key]
  end
  if key == "main" then
    return self._main:get()
  end
end

function M:__newindex(key, value)
  if key == "main" then
    self._main:set(value)
  else
    rawset(self, key, value)
  end
end

---@param opts? {source?: string, tab?: boolean}
function M.get(opts)
  opts = opts or {}
  local ret = {} ---@type snacks.Picker[]
  for picker in pairs(M._active) do
    local want = (not opts.source or picker.opts.source == opts.source)
      and (opts.tab == false or picker:on_current_tab())
      and not picker.closed
    if want then
      ret[#ret + 1] = picker
    end
  end
  table.sort(ret, function(a, b)
    return a.id < b.id
  end)
  return ret
end

---@hide
---@param opts? snacks.picker.Config
---@return snacks.Picker
function M.new(opts)
  ---@type snacks.Picker
  local self = setmetatable({}, M)
  _id = _id + 1
  self.id = _id
  self.init_opts = opts
  self.opts = Snacks.picker.config.get(opts)

  self.history = require("snacks.picker.util.history").new("picker_" .. (self.opts.source or "custom"), {
    ---@param hist snacks.picker.history.Record
    filter = function(hist)
      if hist.pattern == "" and hist.search == "" then
        return false
      end
      return true
    end,
  })

  self:cleanup()

  self.visual = Snacks.picker.util.visual()
  self.start_time = uv.hrtime()
  self._main = require("snacks.picker.core.main").new(self.opts.main)
  local actions = require("snacks.picker.core.actions").get(self)
  self.opts.win.input.actions = actions
  self.opts.win.list.actions = actions
  self.opts.win.preview.actions = actions

  self.sort = Snacks.picker.config.sort(self.opts)

  self.updater = assert(uv.new_timer())
  self.matcher = require("snacks.picker.core.matcher").new(self.opts.matcher)

  self.finder = Finder.new(Snacks.picker.config.finder(self.opts.finder) or function()
    return self.opts.items or {}
  end)

  self.format = Snacks.picker.config.format(self.opts)

  M._pickers[self] = true
  M._active[self] = true

  local layout = Snacks.picker.config.layout(self.opts)
  self.resolved_layout = layout
  self.list = require("snacks.picker.core.list").new(self)
  self.input = require("snacks.picker.core.input").new(self)
  self.preview = require("snacks.picker.core.preview").new(self)

  self.title = self.opts.title or Snacks.picker.util.title(self.opts.source or "search")

  self:init_layout(layout)

  local ref = self:ref()
  self._throttled_preview = Snacks.util.throttle(function()
    local this = ref()
    if this then
      this:_show_preview()
    end
  end, { ms = 60, name = "preview" })

  if not (opts and opts.find == false) then
    self:find()
  end
  return self
end

function M:is_focused()
  return self:current_win() ~= nil
end

---@return string? name, snacks.win? win
function M:current_win()
  local current = vim.api.nvim_get_current_win()
  for w, win in pairs(self.layout.wins or {}) do
    if win.win == current then
      return w, win
    end
  end
end

--- Check if any remnants of previous pickers need to be cleaned up.
--- Normally not needed.
---@private
function M:cleanup()
  local picker_count = vim.tbl_count(M._pickers) - vim.tbl_count(M._active)
  if picker_count > 0 then
    -- clear items from previous pickers for garbage collection
    for picker, _ in pairs(M._pickers) do
      if not M._active[picker] then
        picker.finder.items = {}
        picker.list.items = {}
        picker.list:clear()
        picker.list.picker = nil
      end
    end
  end

  if self.opts.debug.leaks and picker_count > 0 then
    collectgarbage("collect")
    picker_count = vim.tbl_count(M._pickers)
    if picker_count > 0 then
      local pickers = vim.tbl_keys(M._pickers) ---@type snacks.Picker[]
      table.sort(pickers, function(a, b)
        return a.id < b.id
      end)
      local lines = { ("# ` %d ` active pickers:"):format(picker_count) }
      for _, picker in ipairs(pickers) do
        lines[#lines + 1] = ("- [%s]: **pattern**=%q, **search**=%q"):format(
          picker.opts.source or "custom",
          picker.input.filter.pattern,
          picker.input.filter.search
        )
      end
      Snacks.notify.error(lines, { title = "Snacks Picker", id = "snacks_picker_leaks" })
      Snacks.debug.metrics()
    else
      Snacks.notify(
        "Picker leaks cleared after `collectgarbage`",
        { title = "Snacks Picker", id = "snacks_picker_leaks" }
      )
    end
  end
end

function M:on_current_tab()
  return self.layout:valid() and self.layout.root:on_current_tab()
end

--- Execute the callback in normal mode.
--- When still in insert mode, stop insert mode first,
--- and then`vim.schedule` the callback.
---@param cb fun()
function M:norm(cb)
  if vim.fn.mode():sub(1, 1) == "i" then
    vim.cmd.stopinsert()
    vim.schedule(cb)
    return
  end
  cb()
  return true
end

---@param layout? snacks.picker.layout.Config
---@private
function M:init_layout(layout)
  layout = layout or Snacks.picker.config.layout(self.opts)
  self.resolved_layout = vim.deepcopy(layout)
  self.resolved_layout.cycle = self.resolved_layout.cycle == true
  self.preview:update(self)
  local opts = layout --[[@as snacks.layout.Config]]
  local backdrop = nil
  if self.preview.main then
    backdrop = false
  end
  self.layout = Snacks.layout.new(vim.tbl_deep_extend("force", opts, {
    show = false,
    win = {
      wo = {
        winhighlight = Snacks.picker.highlight.winhl("SnacksPicker"),
      },
    },
    wins = {
      input = self.input.win,
      list = self.list.win,
      preview = self.preview.win,
    },
    hidden = layout.hidden,
    on_close = function()
      self:close()
    end,
    on_update = function()
      self.preview:refresh(self)
      self.input:update()
      self.list:update({ force = true })
      self:update_titles()
    end,
    on_update_pre = function()
      self:update_titles()
    end,
    layout = {
      backdrop = backdrop,
    },
  }))
  self:attach()

  -- apply box highlight groups
  local boxwhl = Snacks.picker.highlight.winhl("SnacksPickerBox")
  for _, win in pairs(self.layout.box_wins) do
    win.opts.wo.winhighlight = Snacks.util.winhl(boxwhl, win.opts.wo.winhighlight)
  end
  return layout
end

--- Attaches to the layout
---@private
function M:attach()
  -- Check if we need to load another layout
  self.layout.root:on("VimResized", function()
    vim.schedule(function()
      self:set_layout(Snacks.picker.config.layout(self.opts))
    end)
  end)

  -- close if we enter a window that is not part of the picker
  local preview = false
  self.layout.root:on("WinEnter", function()
    if vim.v.vim_did_enter == 0 then
      return
    end
    if self.closed or Snacks.util.is_float() then
      return
    end
    if self:is_focused() then
      if preview then -- re-open preview when needed
        self:toggle("preview", { enable = true })
        preview = false
      end
      return
    end
    -- close main preview when auto_close is disabled
    if self.opts.auto_close == false then
      if self.preview.main and self.preview.win:valid() then
        self:toggle("preview", { enable = false })
        preview = true
      end
      return
    end
    -- close picker when we enter another window
    vim.schedule(function()
      self:close()
    end)
  end)

  -- Check if we need to auto close any picker windows
  self.layout.root:on("WinEnter", function()
    if not self:is_focused() then
      return
    end
    local current = self:current_win()
    for name, win in pairs(self.layout.wins) do
      local auto_hide = vim.tbl_contains(self.resolved_layout.auto_hide or {}, name)
      if name ~= current and auto_hide and win:valid() then
        self:toggle(name, { enable = false })
      end
    end
  end)

  -- prevent entering the root window for split layouts
  local left_picker = true -- left a picker window
  local last_pwin ---@type number?
  self.layout.root:on("WinLeave", function()
    left_picker = self:is_focused()
  end)
  self.layout.root:on("WinEnter", function()
    if self:is_focused() then
      last_pwin = vim.api.nvim_get_current_win()
    end
  end)
  self.layout.root:on("WinEnter", function()
    if left_picker then
      local pos = self.layout.root.opts.position
      local wincmds = { left = "l", right = "h", top = "j", bottom = "k" }
      vim.cmd("wincmd " .. wincmds[pos])
    elseif last_pwin and vim.api.nvim_win_is_valid(last_pwin) then
      vim.api.nvim_set_current_win(last_pwin)
    else
      self:focus()
    end
  end, { buf = true, nested = true })
end

--- Set the picker layout. Can be either the name of a preset layout
--- or a custom layout configuration.
---@param layout? string|snacks.picker.layout.Config
function M:set_layout(layout)
  layout = layout or Snacks.picker.config.layout(self.opts)
  layout = type(layout) == "string" and Snacks.picker.config.layout(layout) or layout
  ---@cast layout snacks.picker.layout.Config
  layout.cycle = layout.cycle == true
  if vim.deep_equal(layout, self.resolved_layout) then
    -- no need to update
    return
  end
  if self.list.reverse ~= layout.reverse then
    Snacks.notify.warn(
      "Heads up! This layout changed the list order,\nso `up` goes down and `down` goes up.",
      { title = "Snacks Picker", id = "snacks_picker_layout_change" }
    )
  end
  self.list.reverse = layout.reverse
  self.layout.opts.on_close = nil -- prevent closing the picker when changing layout
  self.layout:close({ wins = false })
  self:init_layout(layout)
  self.layout:show()
end

-- Get the word under the cursor or the current visual selection
function M:word()
  return self.visual and self.visual.text or vim.fn.expand("<cword>")
end

--- Update title templates
---@hide
function M:update_titles()
  local data = {
    source = self.title,
    title = self.title,
    live = self.opts.live and self.opts.icons.ui.live or "",
    preview = vim.trim(self.preview.title or ""),
  }
  local toggles = {} ---@type snacks.picker.Text[]
  for name, toggle in pairs(self.opts.toggles) do
    if toggle then
      toggle = type(toggle) == "string" and { icon = toggle } or toggle
      toggle = toggle == true and { icon = name:sub(1, 1) } or toggle
      toggle = toggle == false and { enabled = false } or toggle
      local want = toggle.value
      if toggle.value == nil then
        want = true
      end
      ---@cast toggle snacks.picker.toggle
      if toggle.enabled ~= false and self.opts[name] == want then
        local hl = table.concat(vim.tbl_map(function(a)
          return a:sub(1, 1):upper() .. a:sub(2)
        end, vim.split(name, "_")))
        toggles[#toggles + 1] = { " " .. toggle.icon .. " ", "SnacksPickerToggle" .. hl }
        toggles[#toggles + 1] = { " ", "FloatTitle" }
      end
    end
  end
  local wins = { self.layout.root }
  vim.list_extend(wins, vim.tbl_values(self.layout.wins))
  vim.list_extend(wins, vim.tbl_values(self.layout.box_wins))
  for _, win in pairs(wins) do
    if win.opts.title then
      local tpl = win.meta.title_tpl or win.opts.title
      win.meta.title_tpl = tpl
      tpl = type(tpl) == "string" and { { tpl, "FloatTitle" } } or tpl
      ---@cast tpl snacks.picker.Text[]

      local has_flags = false
      local ret = {} ---@type snacks.picker.Text[]
      for _, chunk in ipairs(tpl) do
        local text = chunk[1]
        if text:find("{flags}", 1, true) then
          text = text:gsub("{flags}", "")
          has_flags = true
        end
        text = vim.trim(Snacks.picker.util.tpl(text, data)):gsub("([%w%p])%s+", "%1 ")
        if text ~= "" then
          -- HACK: add extra space when last char is non word like an icon
          text = text:sub(-1):match("[%w%p]") and text or text .. " "
          ret[#ret + 1] = { text, chunk[2] }
        end
      end
      if #ret > 0 then
        table.insert(ret, { " ", "FloatTitle" })
        table.insert(ret, 1, { " ", "FloatTitle" })
      end
      if has_flags and #toggles > 0 then
        vim.list_extend(ret, toggles)
      end
      win:set_title(ret)
    end
  end
end

--- Actual preview code
---@hide
function M:_show_preview()
  if self.closed then
    return
  end
  if self.opts.on_change then
    self.opts.on_change(self, self:current())
  end
  if not (self.preview and self.preview.win:valid()) then
    return
  end
  self.preview:show(self)
  self:update_titles()
end

-- Throttled preview
M._throttled_preview = M._show_preview

-- Show the preview. Show instantly when no item is yet in the preview,
-- otherwise throttle the preview.
function M:show_preview()
  if self.closed then
    return
  end
  -- don't show preview when cursor is not on target
  if self.list.target then
    return
  end
  if not self.preview.item then
    return self:_show_preview()
  end
  return self:_throttled_preview()
end

---@hide
function M:show()
  if self.shown or self.closed then
    return
  end
  self.shown = true
  self.layout:show()
  if self.opts.focus ~= false and self.opts.enter ~= false then
    self:focus()
  end
  if self.opts.on_show then
    self.opts.on_show(self)
  end
end

--- Focuses the given or configured window.
--- Falls back to the first available window if the window is hidden.
---@param win? "input"|"list"|"preview"
---@param opts? {show?: boolean} when enable is true, the window will be shown if hidden
function M:focus(win, opts)
  opts = opts or {}
  if win and opts.show and self.layout:is_hidden(win) then
    return self:toggle(win, { enable = true, focus = true })
  end
  win = win or self.opts.focus or "input"
  local ret ---@type snacks.win?
  for _, name in ipairs({ "input", "list", "preview" }) do
    local w = self.layout.wins[name]
    if w and w:valid() and not self.layout:is_hidden(name) then
      if name == win then
        ret = w
        break
      end
      ret = ret or w
    end
  end
  if ret then
    ret:focus()
  end
end

--- Toggle the given window and optionally focus
---@param win "input"|"list"|"preview"
---@param opts? {enable?: boolean, focus?: boolean|string}
function M:toggle(win, opts)
  opts = opts or {}
  self.layout:toggle(win, opts.enable, function(enabled)
    -- called if changed and before updating the layout
    local focus = opts.focus == true and win or opts.focus or self:current_win() --[[@as string]]
    if not focus then
      return
    end
    if not enabled then
      -- make sure we don't lose focus when toggling off
      self:focus(focus)
    else
      --- schedule to focus after the layout is updated
      vim.schedule(function()
        self:focus(focus)
      end)
    end
  end)
end

---@param item snacks.picker.Item?
function M:resolve(item)
  if not item then
    return
  end
  Snacks.picker.util.resolve(item)
  Snacks.picker.util.resolve_loc(item)
  return item
end

--- Returns an iterator over the filtered items in the picker.
--- Items will be in sorted order.
---@return fun():(snacks.picker.Item?, number?)
function M:iter()
  local i = 0
  local n = self.list:count()
  return function()
    i = i + 1
    if i <= n then
      return self:resolve(self.list:get(i)), i
    end
  end
end

--- Get all filtered items in the picker.
function M:items()
  local ret = {} ---@type snacks.picker.Item[]
  for item in self:iter() do
    ret[#ret + 1] = item
  end
  return ret
end

--- Get the current item at the cursor
---@param opts? {resolve?: boolean} default is `true`
function M:current(opts)
  opts = opts or {}
  local ret = self.list:current()
  if ret and opts.resolve ~= false then
    ret = self:resolve(ret)
  end
  return ret
end

--- Returns the directory of the current item or the cwd.
--- When the item is a directory, return item path,
--- otherwise return the directory of the item.
function M:dir()
  local item = self:current()
  if item then
    return Snacks.picker.util.dir(item)
  end
  return self:cwd()
end

--- Get the selected items.
--- If `fallback=true` and there is no selection, return the current item.
---@param opts? {fallback?: boolean} default is `false`
---@return snacks.picker.Item[]
function M:selected(opts)
  opts = opts or {}
  local ret = vim.deepcopy(self.list.selected)
  if #ret == 0 and opts.fallback then
    ret = { self:current() }
  end
  return vim.tbl_map(function(item)
    return self:resolve(item)
  end, ret)
end

--- Total number of items in the picker
function M:count()
  return self.finder:count()
end

--- Check if the picker is empty
function M:empty()
  return self:count() == 0
end

---@return snacks.Picker.ref
function M:ref()
  return Snacks.util.ref(self)
end

--- Close the picker
function M:close()
  self.input:stopinsert()
  if self.closed then
    return
  end

  if self.opts.on_close then
    self.opts.on_close(self)
  end

  self:hist_record(true)
  self.closed = true

  for toggle in pairs(self.opts.toggles) do
    self.init_opts[toggle] = self.opts[toggle]
  end

  require("snacks.picker.resume").add(self)

  local current = vim.api.nvim_get_current_win()
  local is_picker_win = vim.tbl_contains({ self.input.win.win, self.list.win.win, self.preview.win.win }, current)
  if is_picker_win and vim.api.nvim_win_is_valid(self.main) then
    pcall(vim.api.nvim_set_current_win, self.main)
  end
  self.updater:stop()
  if not self.updater:is_closing() then
    self.updater:close()
  end
  self.finder:abort()
  self.matcher:abort()
  M._active[self] = nil
  vim.schedule(function()
    self.finder:close()
    self.matcher:close()
    self.layout:close()
    self.list:close()
    self.input:close()
    self.preview:close()
    self.resolved_layout = nil
    self.preview = nil
    self.matcher = nil
    self.updater = nil
    self.history = nil
  end)
end

--- Check if the finder or matcher is running
function M:is_active()
  return self.finder:running() or self.matcher:running()
end

---@private
function M:progress(ms)
  if self.updater:is_active() or self.closed then
    return
  end
  local ref = self:ref()
  self.updater = vim.defer_fn(function()
    local self = ref()
    if not self then
      return
    end
    self:update()
    if not self.closed and self:is_active() then
      -- slower progress when we filled topk
      local topk, height = self.list.topk:count(), self.list.state.height or 50
      self:progress(topk > height and 30 or 10)
    end
  end, ms or 10)
end

---@hide
---@param opts? {force?: boolean}
function M:update(opts)
  opts = opts or {}
  if self.closed then
    return
  end

  -- Schedule the update if we are in a fast event
  if vim.in_fast_event() then
    return vim.schedule(function()
      self:update(opts)
    end)
  end

  local count = self.finder:count()
  local list_count = self.list:count()
  -- Check if we should show the picker
  if not self.shown then
    -- Always show live pickers
    if self.opts.live then
      self:show()
    elseif not self:is_active() then
      if count == 0 and not self.opts.show_empty then
        -- no results found
        local msg = "No results"
        if self.opts.source then
          msg = ("No results found for `%s`"):format(self.opts.source)
        end
        Snacks.notify.warn(msg, { title = "Snacks Picker" })
        self:close()
        return
      elseif count == 1 and self.opts.auto_confirm then
        -- auto confirm if only one result
        self:action("confirm")
        self:close()
        return
      else
        -- show the picker if we have results
        self.list:unpause()
        self:show()
      end
    elseif vim.uv.hrtime() - self.start_time > (self.opts.show_delay * 1e6) then
      -- show the picker after show_delay ms if there are no results yet
      self:show()
    elseif list_count > 1 or (list_count == 1 and not self.opts.auto_confirm) then -- show the picker if we have results
      self:show()
    end
  end

  if self.shown then
    if not self:is_active() or list_count > 3 then
      self.list:unpause()
    end
    -- update list and input
    if not self.input.paused then
      self.input:update()
    end
    self.list:update(opts)
  end
end

--- Execute the given action(s)
---@param actions string|string[]
function M:action(actions)
  return self.input.win:execute(actions)
end

--- Add current filter to history
---@param force? boolean
---@private
function M:hist_record(force)
  if not force and not self.history:is_current() then
    return
  end
  self.history:record({
    pattern = self.input.filter.pattern,
    search = self.input.filter.search,
    live = self.opts.live,
  })
end

function M:cwd()
  return self.input.filter.cwd
end

function M:set_cwd(cwd)
  self.input.filter:set_cwd(cwd)
  self.opts.cwd = cwd
end

--- Move the history cursor
---@param forward? boolean
function M:hist(forward)
  self:hist_record()
  if forward then
    self.history:next()
  else
    self.history:prev()
  end
  local hist = self.history:get() --[[@as snacks.picker.history.Record]]
  self.opts.live = hist.live
  self.input:set(hist.pattern, hist.search)
end

--- Clears the selection, set the target to the current item,
--- and refresh the finder and matcher.
function M:refresh()
  self.list:set_selected()
  self.list:set_target()
  self:find({ refresh = true })
end

--- Check if the finder and/or matcher need to run,
--- based on the current pattern and search string.
---@param opts? { on_done?: fun(), refresh?: boolean }
function M:find(opts)
  if self.closed then
    return
  end
  opts = opts or {}
  local filter = self.input.filter:clone({ trim = true })
  local refresh = opts.refresh ~= false
  if filter.opts.transform then
    refresh = filter.opts.transform(self, filter) or refresh
  end
  self:hist_record()

  local finding = false
  if self.finder:init(filter) or refresh then
    finding = true
    self:update_titles()
    if self:count() > 0 then
      -- pause rapid list updates to prevent flickering
      self.list:pause(2000)
    end
    self.finder:run(self)
  end

  -- re-run matcher if finder or pattern changed
  if self.matcher:init(filter.pattern) or finding then
    self.matcher:run(self)
    if opts.on_done then
      if self.matcher.task:running() then
        self.matcher.task:on("done", vim.schedule_wrap(opts.on_done))
      else
        opts.on_done()
      end
    end

    self.input:pause(60)

    self:progress()
  end
end

--- Get the active filter
function M:filter()
  return self.input.filter:clone()
end

return M
