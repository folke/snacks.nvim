local Async = require("snacks.picker.util.async")
local Finder = require("snacks.picker.core.finder")

local uv = vim.uv or vim.loop
Async.BUDGET = 10

---@class snacks.Picker
---@field opts snacks.picker.Config
---@field finder snacks.picker.Finder
---@field format snacks.picker.format
---@field input snacks.picker.input
---@field layout snacks.layout
---@field resolved_layout snacks.picker.layout.Config
---@field list snacks.picker.list
---@field matcher snacks.picker.Matcher
---@field main number
---@field preview snacks.picker.Preview
---@field shown? boolean
---@field sort snacks.picker.sort
---@field updater uv.uv_timer_t
---@field start_time number
---@field source_name string
---@field closed? boolean
---@field hist_idx number
---@field hist_cursor number
---@field visual? snacks.picker.Visual
local M = {}
M.__index = M

--- Keep track of garbage collection
---@type table<snacks.Picker,boolean>
M._pickers = setmetatable({}, { __mode = "k" })
--- These are active, so don't garbage collect them
---@type table<snacks.Picker,boolean>
M._active = {}

---@class snacks.picker.Last
---@field cursor number
---@field topline number
---@field opts snacks.picker.Config
---@field selected snacks.picker.Item[]
---@field filter snacks.picker.Filter

---@type snacks.picker.Last?
M.last = nil

---@type {pattern: string, search: string, live?: boolean}[]
M.history = {}

---@hide
---@param opts? snacks.picker.Config
function M.new(opts)
  local self = setmetatable({}, M)
  self.opts = Snacks.picker.config.get(opts)
  if self.opts.source == "resume" then
    return M.resume()
  end
  self.visual = Snacks.picker.util.visual()
  self.start_time = uv.hrtime()
  Snacks.picker.current = self
  self.main = require("snacks.picker.core.main").get(self.opts.main)
  local actions = require("snacks.picker.core.actions").get(self)
  self.opts.win.input.actions = actions
  self.opts.win.list.actions = actions
  self.opts.win.preview.actions = actions
  self.hist_idx = #M.history + 1
  self.hist_cursor = self.hist_idx

  local sort = self.opts.sort or require("snacks.picker.sort").default()
  sort = type(sort) == "table" and require("snacks.picker.sort").default(sort) or sort
  ---@cast sort snacks.picker.sort
  self.sort = sort

  self.updater = assert(uv.new_timer())
  self.matcher = require("snacks.picker.core.matcher").new(self.opts.matcher)

  self.finder = Finder.new(Snacks.picker.config.finder(self.opts.finder) or function()
    return self.opts.items or {}
  end)

  local format = type(self.opts.format) == "string" and Snacks.picker.format[self.opts.format]
    or self.opts.format
    or Snacks.picker.format.file
  ---@cast format snacks.picker.format
  self.format = format

  M._pickers[self] = true
  M._active[self] = true

  local layout = Snacks.picker.config.layout(self.opts)
  self.list = require("snacks.picker.core.list").new(self)
  self.input = require("snacks.picker.core.input").new(self)
  self.preview = require("snacks.picker.core.preview").new(self.opts, layout.preview == "main" and self.main or nil)

  M.last = {
    opts = self.opts,
    selected = {},
    cursor = self.list.cursor,
    filter = self.input.filter,
    topline = self.list.top,
  }

  self.source_name = Snacks.picker.util.title(self.opts.source or "search")

  -- properly close the picker when the window is closed
  self.input.win:on("WinClosed", function()
    self:close()
  end, { win = true })

  -- close if we enter a window that is not part of the picker
  self.input.win:on("WinEnter", function()
    local current = vim.api.nvim_get_current_win()
    if not vim.tbl_contains({ self.input.win.win, self.list.win.win, self.preview.win.win }, current) then
      vim.schedule(function()
        self:close()
      end)
    end
  end)

  self:init_layout(layout)
  self.input.win:on("VimResized", function()
    vim.schedule(function()
      self:set_layout(Snacks.picker.config.layout(self.opts))
    end)
  end)

  self._throttled_preview = Snacks.util.throttle(function()
    self._show_preview(self)
  end, { ms = 60, name = "preview" })

  self:find()
  return self
end

---@param layout? snacks.picker.layout.Config
---@private
function M:init_layout(layout)
  layout = layout or Snacks.picker.config.layout(self.opts)
  self.resolved_layout = vim.deepcopy(layout)
  self.resolved_layout.cycle = nil -- not needed for applying layout
  local opts = layout --[[@as snacks.layout.Config]]
  local preview_main = layout.preview == "main"
  local preview_hidden = layout.preview == false or preview_main
  local backdrop = nil
  if preview_main then
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
      preview = not preview_main and self.preview.win or nil,
    },
    hidden = { preview_hidden and "preview" or nil },
    on_update = function()
      self:update_titles()
      self:show_preview()
    end,
    layout = {
      backdrop = backdrop,
    },
  }))
  self.preview:update(preview_main and self.main or nil)
  -- apply box highlight groups
  local boxwhl = Snacks.picker.highlight.winhl("SnacksPickerBox")
  for _, win in pairs(self.layout.box_wins) do
    win.opts.wo.winhighlight = boxwhl
  end
  return layout
end

--- Set the picker layout. Can be either the name of a preset layout
--- or a custom layout configuration.
---@param layout? string|snacks.picker.layout.Config
function M:set_layout(layout)
  layout = layout or Snacks.picker.config.layout(self.opts)
  layout = type(layout) == "string" and Snacks.picker.config.layout(layout) or layout
  ---@cast layout snacks.picker.layout.Config
  layout.cycle = nil -- not needed for applying layout
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
  self.layout:close({ wins = false })
  self:init_layout(layout)
  self.layout:show()
  self.list.reverse = layout.reverse
  self.list.dirty = true
  self.list:update()
  self.input:update()
end

-- Get the word under the cursor or the current visual selection
function M:word()
  return self.visual and self.visual.text or vim.fn.expand("<cword>")
end

--- Update title templates
---@hide
function M:update_titles()
  local data = {
    source = self.source_name,
    live = self.opts.live and self.opts.icons.ui.live or "",
    preview = vim.trim(self.preview.title or ""),
  }
  local opts = self.opts --[[@as snacks.picker.files.Config]]
  local flags = {} ---@type snacks.picker.Text[]
  if opts.hidden then
    flags[#flags + 1] = { " " .. self.opts.icons.ui.hidden .. " ", "SnacksPickerFlagHidden" }
    flags[#flags + 1] = { " ", "FloatTitle" }
  end
  if opts.ignored then
    flags[#flags + 1] = { " " .. self.opts.icons.ui.ignored .. " ", "SnacksPickerFlagIgnored" }
    flags[#flags + 1] = { " ", "FloatTitle" }
  end
  local wins = { self.layout.root }
  vim.list_extend(wins, vim.tbl_values(self.layout.wins))
  vim.list_extend(wins, vim.tbl_values(self.layout.box_wins))
  for _, win in pairs(wins) do
    if win.opts.title then
      local tpl = win.meta.title_tpl or win.opts.title
      win.meta.title_tpl = tpl
      local ret = {} ---@type snacks.picker.Text[]
      local title = Snacks.picker.util.tpl(tpl, data)
      if title:find("{flags}", 1, true) then
        title = title:gsub("{flags}", "")
        vim.list_extend(ret, flags)
      end
      title = vim.trim(title):gsub("%s+", " ")
      if title ~= "" then
        -- HACK: add extra space when last char is non word like an icon
        title = title:sub(-1):match("%w") and title or title .. " "
        table.insert(ret, 1, { " " .. title .. " ", "FloatTitle" })
      end
      win:set_title(ret)
    end
  end
end

--- Resume the last picker
---@private
function M.resume()
  local last = M.last
  if not last then
    Snacks.notify.error("No picker to resume")
    return M.new({ source = "pickers" })
  end
  last.opts.pattern = last.filter.pattern
  last.opts.search = last.filter.search
  local ret = M.new(last.opts)
  ret.list:set_selected(last.selected)
  ret.list:update()
  ret.input:update()
  ret.matcher.task:on(
    "done",
    vim.schedule_wrap(function()
      ret.list:view(last.cursor, last.topline)
    end)
  )
  return ret
end

--- Actual preview code
---@hide
function M:_show_preview()
  if self.opts.on_change then
    self.opts.on_change(self, self:current())
  end
  if not self.preview.win:valid() then
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
  if not self.preview.item then
    self:_show_preview()
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
  if self.preview.main then
    self.preview.win:show()
  end
  self.input.win:focus()
  if self.opts.on_show then
    self.opts.on_show(self)
  end
end

--- Returns an iterator over the filtered items in the picker.
--- Items will be in sorted order.
---@return fun():snacks.picker.Item?
function M:iter()
  local i = 0
  local n = self.list:count()
  return function()
    i = i + 1
    if i <= n then
      return self.list:get(i)
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
function M:current()
  return self.list:current()
end

--- Get the selected items.
--- If `fallback=true` and there is no selection, return the current item.
---@param opts? {fallback?: boolean} default is `false`
function M:selected(opts)
  opts = opts or {}
  local ret = vim.deepcopy(self.list.selected)
  if #ret == 0 and opts.fallback then
    return { self:current() }
  end
  return ret
end

--- Total number of items in the picker
function M:count()
  return self.finder:count()
end

--- Check if the picker is empty
function M:empty()
  return self:count() == 0
end

--- Close the picker
function M:close()
  if self.closed then
    return
  end
  vim.cmd.stopinsert()
  self.closed = true
  M.last.selected = self:selected({ fallback = false })
  M.last.cursor = self.list.cursor
  M.last.topline = self.list.top
  Snacks.picker.current = nil
  local current = vim.api.nvim_get_current_win()
  local is_picker_win = vim.tbl_contains({ self.input.win.win, self.list.win.win, self.preview.win.win }, current)
  if is_picker_win and vim.api.nvim_win_is_valid(self.main) then
    vim.api.nvim_set_current_win(self.main)
  end
  self.preview.win:close()
  self.layout:close()
  self.updater:stop()
  M._active[self] = nil
  vim.schedule(function()
    self.list:clear()
    self.finder.items = {}
    self.matcher:abort()
    self.finder:abort()
  end)
end

--- Check if the finder or matcher is running
function M:is_active()
  return self.finder:running() or self.matcher:running()
end

---@private
function M:progress(ms)
  if self.updater:is_active() then
    return
  end
  self.updater = vim.defer_fn(function()
    self:update()
    if self:is_active() then
      -- slower progress when we filled topk
      local topk, height = self.list.topk:count(), self.list.state.height or 50
      self:progress(topk > height and 30 or 10)
    end
  end, ms or 10)
end

---@hide
function M:update()
  if self.closed then
    return
  end

  -- Schedule the update if we are in a fast event
  if vim.in_fast_event() then
    return vim.schedule(function()
      self:update()
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
      if count == 0 then
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
    elseif list_count > 1 or (list_count == 1 and not self.opts.auto_confirm) then -- show the picker if we have results
      self:show()
    end
  end

  if self.shown then
    if not self:is_active() then
      self.list:unpause()
    end
    -- update list and input
    if not self.list.paused then
      self.input:update()
    end
    self.list:update()
  end
end

--- Execute the given action(s)
---@param actions string|string[]
function M:action(actions)
  return self.input.win:execute(actions)
end

--- Clear the list and run the finder and matcher
---@param opts? {on_done?: fun()} Callback when done
function M:find(opts)
  self:update_titles()
  self.finder:run(self)
  self.matcher:run(self)
  if opts and opts.on_done then
    if self.matcher.task:running() then
      self.matcher.task:on("done", vim.schedule_wrap(opts.on_done))
    else
      opts.on_done()
    end
  end
  self:progress()
end

--- Add current filter to history
---@private
function M:hist_record()
  M.history[self.hist_idx] = {
    pattern = self.input.filter.pattern,
    search = self.input.filter.search,
    live = self.opts.live,
  }
end

--- Move the history cursor
---@param forward? boolean
function M:hist(forward)
  self:hist_record()
  self.hist_cursor = self.hist_cursor + (forward and 1 or -1)
  self.hist_cursor = math.min(math.max(self.hist_cursor, 1), #M.history)
  self.opts.live = M.history[self.hist_cursor].live
  self.input:set(M.history[self.hist_cursor].pattern, M.history[self.hist_cursor].search)
end

--- Run the matcher with the current pattern.
--- May also trigger a new find if the search string has changed,
--- like during live searches.
function M:match()
  local pattern = vim.trim(self.input.filter.pattern)
  local search = vim.trim(self.input.filter.search)
  local needs_match = false
  self:hist_record()
  if self.matcher.pattern ~= pattern then
    self.matcher:init({ pattern = pattern })
    needs_match = true
  end

  if self.finder:changed(search) then
    -- pause rapid list updates to prevent flickering
    -- of the search results
    self.list:pause(60)
    return self:find()
  end

  if not needs_match then
    return
  end

  local prios = {} ---@type snacks.picker.Item[]
  -- add current topk items to be checked first
  vim.list_extend(prios, self.list.topk:get())
  if not self.matcher:empty() then
    -- next add the rest of the matched items
    vim.list_extend(prios, self.list.items, 1, 1000)
  end

  self.matcher:run(self, { prios = prios })
  self:progress()
end

--- Get the active filter
function M:filter()
  return self.input.filter:clone()
end

return M
