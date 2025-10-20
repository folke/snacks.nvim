---@class snacks.picker.list
---@field picker snacks.Picker
---@field items snacks.picker.Item[]
---@field top number
---@field cursor number
---@field win snacks.win
---@field dirty boolean
---@field state snacks.picker.list.State
---@field paused boolean
---@field topk snacks.picker.MinHeap
---@field _current? snacks.picker.Item
---@field did_preview? boolean
---@field reverse? boolean
---@field selected snacks.picker.Item[]
---@field selected_map table<string, snacks.picker.Item>
---@field matcher snacks.picker.Matcher matcher for formatting list items
---@field matcher_regex snacks.picker.Matcher matcher for formatting list items
---@field target? {cursor: number, top?: number}
---@field visible snacks.picker.Item[]
local M = {}
M.__index = M

---@class snacks.picker.list.State
---@field height number
---@field scrolloff number
---@field scroll number
---@field mousescroll number

local ns = vim.api.nvim_create_namespace("snacks.picker.list")

local function minmax(value, min, max)
  return math.max(min, math.min(value, max))
end

local SCROLL_WHEEL_UP = Snacks.util.keycode("<ScrollWheelUp>")
local SCROLL_WHEEL_DOWN = Snacks.util.keycode("<ScrollWheelDown>")

---@type table<number, snacks.picker.list>
local lists = setmetatable({}, { __mode = "v" })

local stats = { render = 0, render_full = 0 }

-- track mouse scrolling
vim.on_key(function(key, typed)
  key = typed or key
  if key ~= SCROLL_WHEEL_UP and key ~= SCROLL_WHEEL_DOWN then
    return
  end
  local up = key == SCROLL_WHEEL_UP
  local mouse_win = vim.fn.getmousepos().winid
  local list = lists[mouse_win]
  if list and list.win:valid() then
    vim.schedule(function()
      if list and list.win:valid() then
        list:scroll((up and -1 or 1) * list.state.mousescroll)
      end
    end)
    return "" -- on Neovim 0.11, this will prevent the default scroll
  end
end)

---@param picker snacks.Picker
function M.new(picker)
  local self = setmetatable({}, M)
  self.reverse = picker.resolved_layout.reverse
  self.picker = picker
  self.selected = {}
  self.selected_map = {}
  self.matcher = require("snacks.picker.core.matcher").new(picker.opts.matcher)
  self.matcher_regex = require("snacks.picker.core.matcher").new({ regex = true })
  local win_opts = Snacks.win.resolve(picker.opts.win.list, {
    show = false,
    enter = false,
    on_win = function()
      self:on_show()
      lists[
        self.win.win --[[@as number]]
      ] = self
    end,
    minimal = true,
    bo = { modifiable = false, filetype = "snacks_picker_list" },
    wo = {
      foldenable = false,
      foldmethod = "manual",
      cursorline = false,
      winhighlight = Snacks.picker.highlight.winhl("SnacksPickerList", { CursorLine = "Visual" }),
      linebreak = true,
      breakindent = true,
    },
  })
  self.visible = {}
  self.win = Snacks.win(win_opts)
  self.top, self.cursor = 1, 1
  self.items = {}
  self.state = { height = 0, scrolloff = 0, scroll = 0, mousescroll = 1 }
  self.dirty = true
  self.topk = require("snacks.picker.util.minheap").new({
    capacity = 1000,
    cmp = self.picker.sort,
  })

  self.win:on("CursorMoved", function()
    if not self.win:valid() then
      return
    end
    local cursor = vim.api.nvim_win_get_cursor(self.win.win)
    local view = vim.api.nvim_win_call(self.win.win, vim.fn.winsaveview)
    local row = cursor[1] - view.topline + 1
    if cursor[1] ~= self:idx2row(self.cursor) then
      local idx = self:row2idx(row)
      self:_move(idx, true, true)
    end
  end, { buf = true })

  self.win:on("VimResized", function()
    self.state.height = vim.api.nvim_win_get_height(self.win.win)
    self.dirty = true
    self:update()
  end)

  self.win:on("WinResized", function()
    if vim.tbl_contains(vim.v.event.windows, self.win.win) then
      self.state.height = vim.api.nvim_win_get_height(self.win.win)
      self.dirty = true
      self:update()
    end
  end)

  -- reset topline. Only needed for Neovim < 0.11,
  -- but won't hurt on newer versions
  self.win:on("WinScrolled", function()
    for win in pairs(vim.v.event) do
      if (tonumber(win) or -1) == self.win.win then
        vim.api.nvim_win_call(self.win.win, function()
          vim.fn.winrestview({ topline = 1 })
        end)
      end
    end
  end)

  local focused = false
  self.win:on({ "WinEnter", "WinLeave" }, function()
    local f = vim.api.nvim_get_current_win() == self.win.win
    if focused ~= f then
      focused = f
      self:update_cursorline()
    end
  end)

  return self
end

--- View the list at the given cursor and top.
--- These are the normalized values, so are unaffected by reverse.
---@param cursor number
---@param top? number
---@param render? boolean
function M:view(cursor, top, render)
  if top then
    self:_scroll(top, true, false)
  end
  self:_move(cursor, true, render)
  if self.cursor < cursor then
    self.target = { cursor = cursor, top = top }
  else
    self.target = nil
  end
end

--- Sets the target cursor/top for the next render.
--- Useful to keep the cursor/top, right before triggering a `find`.
--- If an existing target is set, it will be kept, unless `opts.force` is set.
---@param cursor? number
---@param top? number
---@param opts? {force?: boolean}
function M:set_target(cursor, top, opts)
  if self.target and not (opts and opts.force) then
    return
  end
  self.target = { cursor = cursor or self.cursor, top = top or self.top }
end

---@param idx number
function M:idx2row(idx)
  local ret = idx - self.top + 1
  if not self.reverse then
    return ret
  end
  return self.state.height - ret + 1
end

---@param row number
function M:row2idx(row)
  local ret = row + self.top - 1
  if not self.reverse then
    return ret
  end
  return self.state.height - ret + 1
end

function M:on_show()
  self.state.scrolloff = vim.wo[self.win.win].scrolloff
  self.state.scroll = vim.wo[self.win.win].scroll
  self.state.height = vim.api.nvim_win_get_height(self.win.win)
  self.state.mousescroll = tonumber(vim.o.mousescroll:match("ver:(%d+)")) or 1
  Snacks.util.wo(self.win.win, { scrolloff = 0 })
  self.dirty = true
  self:update_cursorline()
  self:update({ force = true })
end

function M:count()
  return #self.items
end

function M:close()
  self.win:destroy()
  self.picker = nil
  for w, l in pairs(lists) do
    if l == self then
      lists[w] = nil
    end
  end
  -- Keep all items so actions can be performed on them,
  -- even when the picker closed
end

function M:scrolloff()
  local scrolloff = math.min(self.state.scrolloff, math.floor((self:height() - 1) / 2))
  local offset = math.min(self.cursor, self:count() - self.cursor)
  return offset > scrolloff and scrolloff or 0
end

---@param to number
---@param absolute? boolean
---@param render? boolean
function M:_scroll(to, absolute, render)
  local old_top = self.top
  self.top = absolute and to or self.top + to
  local maxtop = self:count() - self:height() + 1
  self.top = minmax(self.top, 1, maxtop)
  if self.top == maxtop or self.top == 1 then
    self.cursor = absolute and to or self.cursor + to
  end
  local scrolloff = self:scrolloff()
  self.cursor = minmax(self.cursor, self.top + scrolloff, self.top + self:height() - 1 - scrolloff)
  self.dirty = self.dirty or self.top ~= old_top
  if render ~= false then
    self:render()
  end
end

---@param to number
---@param absolute? boolean
---@param render? boolean
function M:scroll(to, absolute, render)
  if self.reverse then
    to = absolute and (self:count() - to + 1) or -1 * to
  end
  self:_scroll(to, absolute, render)
end

---@param to number
---@param absolute? boolean
---@param render? boolean
function M:_move(to, absolute, render)
  local old_top = self.top
  local height = self:height()
  if height <= 1 then
    self.cursor, self.top = 1, 1
  else
    self.cursor = absolute and to or self.cursor + to
    if self.picker.resolved_layout.cycle then
      self.cursor = (self.cursor - 1) % self:count() + 1
    end
    self.cursor = minmax(self.cursor, 1, self:count())
    local scrolloff = self:scrolloff()
    self.top = minmax(self.top, self.cursor - self:height() + scrolloff + 1, self.cursor - scrolloff)
  end
  self.dirty = self.dirty or self.top ~= old_top
  if render ~= false then
    self:render()
  end
end

---@param to number
---@param absolute? boolean
---@param render? boolean
function M:move(to, absolute, render)
  if self.reverse then
    to = absolute and (self:count() - to + 1) or -1 * to
  end
  self:_move(to, absolute, render)
end

function M:clear()
  self.topk:clear()
  self.top, self.cursor = 1, 1
  self.items = {}
  self.dirty = true
  if next(self.items) == nil then
    return
  end
  self:update()
end

function M:pause(ms)
  self.paused = true
  vim.defer_fn(function()
    self:unpause()
  end, ms)
end

---@param item snacks.picker.Item
---@param sort? boolean
function M:add(item, sort)
  local idx = #self.items + 1
  self.items[idx] = item
  -- if the visible items are less than the height, then we need to render
  self.dirty = self.dirty or #self.visible < (self.state.height or 50)
  if sort ~= false then
    local added, prev = self.topk:add(item)
    if added then
      -- check if item is before the last visible item
      if not self.dirty and #self.visible > 0 then
        self.dirty = self.topk.cmp(item, self.visible[#self.visible])
      end
      item.match_topk = item.match_tick
      if prev then
        -- replace with previous item, since new item is now in topk
        self.items[idx] = prev
        prev.match_topk = nil
      end
    end
  end
end

---@return snacks.picker.Item?
function M:current()
  return self:get(self.cursor)
end

--- Returns the item at the given sorted index.
--- Item will be taken from topk if available, otherwise from items.
--- In case the matcher is running, the item will be taken from the finder.
---@param idx number
---@return snacks.picker.Item?
function M:get(idx)
  return self.topk:get(idx) or self.items[idx]
end

function M:height()
  return math.min(self.state.height, self:count())
end

---@param opts? {force?: boolean}
function M:update(opts)
  if opts and opts.force then
    self.dirty = true
  end
  if vim.in_fast_event() then
    return vim.schedule(function()
      self:update()
    end)
  end
  if self.paused and #self.items < self.state.height then
    return
  end
  self:render()
end

-- Toggle selection of current item
---@param item? snacks.picker.Item
function M:select(item)
  if item == nil and vim.fn.mode():find("^[vV]") and vim.api.nvim_get_current_buf() == self.win.buf then
    -- stop visual mode
    vim.cmd("normal! " .. vim.fn.mode():sub(1, 1))
    local from = vim.api.nvim_buf_get_mark(0, "<")
    local to = vim.api.nvim_buf_get_mark(0, ">")
    for i = math.min(from[1], to[1]), math.max(from[1], to[1]) do
      local it = self:get(self:row2idx(i))
      if it then
        self:select(it)
      end
    end
    return
  end
  item = item or self:current()
  if not item then
    return
  end
  if self:unselect(item) then
    return
  end
  local key = self:select_key(item)
  self.selected_map[key] = item
  table.insert(self.selected, item)
  self.picker.input:update()
  self.dirty = true
  self:render()
end

---@param item? snacks.picker.Item
function M:unselect(item)
  item = item or self:current()
  if not item then
    return
  end
  local key = self:select_key(item)
  if not self.selected_map[key] then
    return
  end
  self.selected_map[key] = nil
  self.selected = vim.tbl_filter(function(v)
    return self:select_key(v) ~= key
  end, self.selected)
  self.picker.input:update()
  self.dirty = true
  self:render()
  return true
end

function M:select_all()
  self:set_selected(#self.selected == self:count() and {} or self.items)
end

---@param item snacks.picker.Item
---@return string
function M:select_key(item)
  item._select_key = item._select_key
    or Snacks.picker.util.text(item, { "text", "file", "key", "id", "pos", "end_pos" })
  return item._select_key
end

---@param items? snacks.picker.Item[]
function M:set_selected(items)
  items = items or {}
  self.selected = items
  self.selected_map = {}
  for _, item in ipairs(items) do
    self.selected_map[self:select_key(item)] = item
  end
  self.picker.input:update()
  self.dirty = true
  self:update()
end

---@param item snacks.picker.Item
function M:is_selected(item)
  return self.selected_map[self:select_key(item)] ~= nil
end

function M:unpause()
  if not self.paused then
    return
  end
  self.paused = false
  self:update()
end

---@param item snacks.picker.Item
function M:format(item)
  Snacks.picker.util.resolve(item)
  -- Add selected and debug info
  local prefix = {} ---@type snacks.picker.Highlight[]
  if #self.selected > 0 or self.picker.opts.formatters.selected.show_always then
    vim.list_extend(prefix, Snacks.picker.format.selected(item, self.picker))
  else
    prefix[#prefix + 1] = { " " }
  end
  if self.picker.opts.debug.scores then
    vim.list_extend(prefix, Snacks.picker.format.debug(item, self.picker))
  end
  local text, extmarks = Snacks.picker.highlight.to_text(prefix)

  -- Add the formatted item
  local line = self.picker.format(item, self.picker)
  while #line > 0 and type(line[#line][1]) == "string" and line[#line][1]:find("^%s*$") do
    table.remove(line)
  end
  local line_text, line_extmarks = Snacks.picker.highlight.to_text(line, { offset = #text })
  vim.list_extend(extmarks, line_extmarks)
  text = text .. line_text

  -- Highlight match positions for field patterns
  local fields = self.matcher:fields()
  for _, extmark in ipairs(extmarks) do
    if extmark.col and extmark.end_col and extmark.field and vim.tbl_contains(fields, extmark.field) then
      local field = extmark.field --[[@as string]]
      ---@type snacks.picker.Item
      local it = {
        idx = 1,
        score = 0,
        file = item.file,
        text = "",
      }
      it[field] = text:sub(extmark.col + 1, extmark.end_col)
      local positions = self.matcher:positions(it)
      for _, pos in ipairs(positions[field] or {}) do
        table.insert(extmarks, {
          col = pos - 1 + extmark.col,
          end_col = pos + extmark.col,
          hl_group = "SnacksPickerMatch",
        })
      end
    end
  end

  -- Highlight match positions for text
  local it = { text = text:gsub("%s*$", ""), idx = 1, score = 0, file = item.file }
  local positions = self.matcher:positions(it).text or {}
  vim.list_extend(positions, self.matcher_regex:positions(it).text or {})
  for _, pos in ipairs(positions) do
    table.insert(extmarks, {
      col = pos - 1,
      end_col = pos,
      hl_group = "SnacksPickerMatch",
    })
  end
  return text, extmarks
end

---@param item snacks.picker.Item
---@param row number
function M:_render(item, row)
  local text, extmarks = self:format(item)
  text = text:gsub("\n", " ")
  vim.api.nvim_buf_set_lines(self.win.buf, row - 1, row, false, { text })
  for _, extmark in ipairs(extmarks) do
    local col = extmark.col
    extmark.col = nil
    extmark.row = nil
    extmark.field = nil
    local ok, err = pcall(vim.api.nvim_buf_set_extmark, self.win.buf, ns, row - 1, col, extmark)
    if not ok and self.picker.opts.debug.extmarks then
      Snacks.notify.error("Failed to set extmark.\n" .. err .. "\n```lua\n" .. vim.inspect(extmark) .. "\n```")
    end
  end
end

function M:update_cursorline()
  if self.win:win_valid() then
    Snacks.util.wo(self.win.win, {
      cursorline = self:count() > 0,
      winhighlight = Snacks.util.winhl(vim.wo[self.win.win].winhighlight, {
        CursorLine = self.picker:is_focused() and "SnacksPickerListCursorLine" or "CursorLine",
      }),
    })
  end
end

function M:render()
  if not self.win:valid() then
    return
  end
  stats.render = stats.render + 1
  if self.target then
    self:view(self.target.cursor, self.target.top, false)
    if not self.picker:is_active() then
      self.target = nil
    end
  else
    self:move(0, false, false)
    self:scroll(0, false, false)
  end

  local redraw = false
  if self.dirty then
    stats.render_full = stats.render_full + 1
    local height = self:height()
    self.dirty = false
    vim.api.nvim_win_call(self.win.win, function()
      vim.fn.winrestview({ topline = 1, leftcol = 0 })
    end)

    vim.api.nvim_buf_clear_namespace(self.win.buf, ns, 0, -1)

    vim.bo[self.win.buf].modifiable = true
    local lines = vim.split(string.rep("\n", self.state.height), "\n")
    vim.api.nvim_buf_set_lines(self.win.buf, 0, -1, false, lines)

    -- matcher for highlighting should include the search filter
    local pattern = vim.trim(self.picker.input.filter.pattern)
    if self.matcher.pattern ~= pattern then
      self.matcher:init(pattern)
    end
    local search = Snacks.picker.util.parse(vim.trim(self.picker.input.filter.search))
    if self.matcher_regex.pattern ~= search then
      self.matcher_regex:init(search)
    end

    self.visible = {}
    -- render items
    for i = self.top, math.min(self:count(), self.top + height - 1) do
      local item = assert(self:get(i), "item not found")
      self.visible[i - self.top + 1] = item
      local row = self:idx2row(i)
      self:_render(item, row)
    end

    vim.bo[self.win.buf].modifiable = false
    redraw = true
  end

  -- Fix cursor and cursorline
  self:update_cursorline()
  local cursor = vim.api.nvim_win_get_cursor(self.win.win)
  if cursor[1] ~= self:idx2row(self.cursor) then
    vim.api.nvim_win_set_cursor(self.win.win, { self:idx2row(self.cursor), 0 })
  end

  -- force redraw if list changed
  if redraw then
    self.win:redraw()
  end

  if self.target then
    return
  end

  -- check if current item changed
  local current = self:current()
  if self._current ~= current then
    self._current = current
    if not self.did_preview then
      -- show first preview instantly
      self.did_preview = true
      self.picker:show_preview()
    else
      vim.schedule(function()
        if self.picker then
          self.picker:show_preview()
        end
      end)
    end
  end
end

-- vim.uv.new_timer():start(
--   500,
--   500,
--   vim.schedule_wrap(function()
--     Snacks.notify(vim.inspect(stats), { ft = "lua", id = "list_stats" })
--   end)
-- )

return M
