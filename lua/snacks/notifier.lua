---@class snacks.notifier
---@overload fun(msg: string, level?: snacks.notifier.level|number, opts?: snacks.notifier.Notif.opts): number|string
local M = setmetatable({}, {
  __call = function(t, ...)
    return t.notify(...)
  end,
})

M.meta = {
  desc = "Pretty `vim.notify`",
  needs_setup = true,
}

local uv = vim.uv or vim.loop

--- Render styles:
--- * compact: use border for icon and title
--- * minimal: no border, only icon and message
--- * fancy: similar to the default nvim-notify style
---@alias snacks.notifier.style snacks.notifier.render|"compact"|"fancy"|"minimal"

--- ### Notifications
---
--- Notification options
---@class snacks.notifier.Notif.opts
---@field id? number|string
---@field msg? string
---@field level? number|snacks.notifier.level
---@field title? string
---@field icon? string
---@field timeout? number|boolean timeout in ms. Set to 0|false to keep until manually closed
---@field ft? string
---@field keep? fun(notif: snacks.notifier.Notif): boolean
---@field style? snacks.notifier.style
---@field opts? fun(notif: snacks.notifier.Notif) -- dynamic opts
---@field hl? snacks.notifier.hl -- highlight overrides
---@field history? boolean

--- Notification object
---@class snacks.notifier.Notif: snacks.notifier.Notif.opts
---@field id number|string
---@field msg string
---@field win? snacks.win
---@field icon string
---@field level snacks.notifier.level
---@field timeout number
---@field dirty? boolean
---@field added number timestamp with nano precision
---@field updated number timestamp with nano precision
---@field shown? number timestamp with nano precision
---@field hidden? number timestamp with nano precision
---@field layout? { top?: number, width: number, height: number }

--- ### Rendering
---@alias snacks.notifier.render fun(buf: number, notif: snacks.notifier.Notif, ctx: snacks.notifier.ctx)

---@class snacks.notifier.hl
---@field title string
---@field icon string
---@field border string
---@field footer string
---@field msg string

---@class snacks.notifier.ctx
---@field opts snacks.win.Config
---@field notifier snacks.notifier.Class
---@field hl snacks.notifier.hl
---@field ns number

--- ### History
---@class snacks.notifier.history
---@field filter? vim.log.levels|snacks.notifier.level|fun(notif: snacks.notifier.Notif): boolean
---@field sort? string[] # sort fields, default: {"added"}
---@field reverse? boolean

---@type snacks.notifier.history
local history_opts = {
  sort = { "added" },
}

Snacks.config.style("notification", {
  border = true,
  zindex = 100,
  ft = "markdown",
  wo = {
    winblend = 5,
    wrap = false,
    conceallevel = 2,
    colorcolumn = "",
  },
  bo = { filetype = "snacks_notif" },
})

Snacks.config.style("notification_history", {
  border = true,
  zindex = 100,
  width = 0.6,
  height = 0.6,
  minimal = false,
  title = " Notification History ",
  title_pos = "center",
  ft = "markdown",
  bo = { filetype = "snacks_notif_history", modifiable = false },
  wo = { winhighlight = "Normal:SnacksNotifierHistory" },
  keys = { q = "close" },
})

---@class snacks.notifier.Config
---@field enabled? boolean
---@field keep? fun(notif: snacks.notifier.Notif): boolean # global keep function
---@field filter? fun(notif: snacks.notifier.Notif): boolean # filter our unwanted notifications (return false to hide)
local defaults = {
  timeout = 3000, -- default timeout in ms
  width = { min = 40, max = 0.4 },
  height = { min = 1, max = 0.6 },
  -- editor margin to keep free. tabline and statusline are taken into account automatically
  margin = { top = 0, right = 1, bottom = 0 },
  padding = true, -- add 1 cell of left/right padding to the notification window
  sort = { "level", "added" }, -- sort by level and time
  -- minimum log level to display. TRACE is the lowest
  -- all notifications are stored in history
  level = vim.log.levels.TRACE,
  icons = {
    error = " ",
    warn = " ",
    info = " ",
    debug = " ",
    trace = " ",
  },
  keep = function(notif)
    return vim.fn.getcmdpos() > 0
  end,
  ---@type snacks.notifier.style
  style = "compact",
  top_down = true, -- place notifications from top to bottom
  date_format = "%R", -- time format for notifications
  -- format for footer when more lines are available
  -- `%d` is replaced with the number of lines.
  -- only works for styles with a border
  ---@type string|boolean
  more_format = " ↓ %d lines ",
  refresh = 50, -- refresh at most every 50ms
}

---@class snacks.notifier.Class
---@field queue table<string|number, snacks.notifier.Notif>
---@field history table<string|number, snacks.notifier.Notif>
---@field sorted? snacks.notifier.Notif[]
---@field opts snacks.notifier.Config
local N = {}

N.ns = vim.api.nvim_create_namespace("snacks.notifier")

---@param str string
local function cap(str)
  return str:sub(1, 1):upper() .. str:sub(2):lower()
end

---@param name string
---@param level? snacks.notifier.level
local function hl(name, level)
  return "SnacksNotifier" .. name .. (level and cap(level) or "")
end

---@type table<string, snacks.notifier.render>
N.styles = {
  -- style using border title
  compact = function(buf, notif, ctx)
    local title = vim.trim(notif.icon .. " " .. (notif.title or ""))
    if title ~= "" then
      ctx.opts.title = { { " " .. title .. " ", ctx.hl.title } }
      ctx.opts.title_pos = "center"
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(notif.msg, "\n"))
  end,
  minimal = function(buf, notif, ctx)
    ctx.opts.border = "none"
    local whl = ctx.opts.wo.winhighlight
    ctx.opts.wo.winhighlight = whl:gsub(ctx.hl.msg, "SnacksNotifierMinimal")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(notif.msg, "\n"))
    vim.api.nvim_buf_set_extmark(buf, ctx.ns, 0, 0, {
      virt_text = { { notif.icon, ctx.hl.icon } },
      virt_text_pos = "right_align",
    })
  end,
  history = function(buf, notif, ctx)
    local lines = vim.split(notif.msg, "\n", { plain = true })
    local prefix = {
      { os.date(ctx.notifier.opts.date_format, notif.added), hl("HistoryDateTime") },
      { notif.icon, ctx.hl.icon },
      { notif.level:upper(), ctx.hl.title },
      { notif.title, hl("HistoryTitle") },
    }
    prefix = vim.tbl_filter(function(v)
      return (v[1] or "") ~= ""
    end, prefix)
    local prefix_width = 0
    for i = 1, #prefix do
      prefix_width = prefix_width + vim.fn.strdisplaywidth(prefix[i * 2 - 1][1]) + 1
      table.insert(prefix, i * 2, { " " })
    end
    local top = vim.api.nvim_buf_line_count(buf)
    local empty = top == 1 and #vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == 0
    top = empty and 0 or top
    lines[1] = string.rep(" ", prefix_width) .. (lines[1] or "")
    vim.api.nvim_buf_set_lines(buf, top, -1, false, lines)
    vim.api.nvim_buf_set_extmark(buf, ctx.ns, top, 0, {
      virt_text = prefix,
      virt_text_pos = "overlay",
      priority = 10,
    })
  end,
  -- similar to the default nvim-notify style
  fancy = function(buf, notif, ctx)
    vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "", "" })
    vim.api.nvim_buf_set_lines(buf, 2, -1, false, vim.split(notif.msg, "\n"))
    vim.api.nvim_buf_set_extmark(buf, ctx.ns, 0, 0, {
      virt_text = { { " " }, { notif.icon, ctx.hl.icon }, { " " }, { notif.title or "", ctx.hl.title } },
      virt_text_win_col = 0,
      priority = 10,
    })
    vim.api.nvim_buf_set_extmark(buf, ctx.ns, 0, 0, {
      virt_text = { { " " }, { os.date(ctx.notifier.opts.date_format, notif.added), ctx.hl.title }, { " " } },
      virt_text_pos = "right_align",
      priority = 10,
    })
    vim.api.nvim_buf_set_extmark(buf, ctx.ns, 1, 0, {
      virt_text = { { string.rep("━", vim.o.columns - 2), ctx.hl.border } },
      virt_text_win_col = 0,
      priority = 10,
    })
  end,
}

---@alias snacks.notifier.level "trace"|"debug"|"info"|"warn"|"error"

---@type table<number, snacks.notifier.level>
N.levels = {
  [vim.log.levels.TRACE] = "trace",
  [vim.log.levels.DEBUG] = "debug",
  [vim.log.levels.INFO] = "info",
  [vim.log.levels.WARN] = "warn",
  [vim.log.levels.ERROR] = "error",
}
N.level_names = vim.tbl_values(N.levels) ---@type snacks.notifier.level[]

---@param level number|string
---@return snacks.notifier.level
local function normlevel(level)
  return type(level) == "string" and (vim.tbl_contains(N.level_names, level:lower()) and level:lower() or "info")
    or N.levels[level]
    or "info"
end

---@param level number|string
---@return integer
local function numlevel(level)
  return type(level) == "number" and level or vim.log.levels[normlevel(level):upper()] or 0
end

local function ts()
  if uv.clock_gettime then
    local ret = assert(uv.clock_gettime("realtime"))
    return ret.sec + ret.nsec / 1e9
  end
  local sec, usec = uv.gettimeofday()
  return sec + usec / 1e6
end

local _id = 0

local function next_id()
  _id = _id + 1
  return _id
end

---@param opts? snacks.notifier.Config
---@return snacks.notifier.Class
function N.new(opts)
  local self = setmetatable({}, { __index = N })
  self.opts = Snacks.config.get("notifier", defaults, opts)
  self.queue = {}
  self.history = {}
  self:init()
  self:start()
  return self
end

function N:init()
  local links = {
    [hl("History")] = "Normal",
    [hl("HistoryTitle")] = "Title",
    [hl("HistoryDateTime")] = "Special",
    SnacksNotifierMinimal = "NormalFloat",
  }
  for _, level in ipairs(N.level_names) do
    local Level = cap(level)
    local link = vim.tbl_contains({ "Trace", "Debug" }, Level) and "NonText" or nil
    links[hl("", level)] = "Normal"
    links[hl("Icon", level)] = link or ("DiagnosticSign" .. Level)
    links[hl("Border", level)] = link or ("Diagnostic" .. Level)
    links[hl("Title", level)] = link or ("Diagnostic" .. Level)
    links[hl("Footer", level)] = link or ("Diagnostic" .. Level)
  end
  Snacks.util.set_hl(links, { default = true })

  -- resize handler
  vim.api.nvim_create_autocmd("VimResized", {
    group = vim.api.nvim_create_augroup("snacks_notifier", {}),
    callback = function()
      for _, notif in pairs(self.queue) do
        notif.dirty = true
      end
      self.sorted = nil
    end,
  })
end

function N:start()
  local running = false
  uv.new_timer():start(self.opts.refresh, self.opts.refresh, function()
    if running or not next(self.queue) then
      return
    end
    running = true
    vim.schedule(function()
      if self.in_search() then
        running = false
        return
      end
      xpcall(function()
        self:process()
      end, function(err)
        if err:find("E565") then
          return
        end
        local trace = debug.traceback(2)
        vim.schedule(function()
          vim.api.nvim_err_writeln(
            ("Snacks notifier failed. Dropping queue. Error:\n%s\n\nTrace:\n%s"):format(err, trace)
          )
        end)
        self.queue = {}
      end)
      running = false
    end)
  end)
end

function N:process()
  self:update()
  self:layout()
end

function N:is_blocking()
  local mode = vim.api.nvim_get_mode()
  for _, m in ipairs({ "ic", "ix", "c", "no", "r%?", "rm" }) do
    if mode.mode:find(m) == 1 then
      return true
    end
  end
  return mode.blocking
end

local health_msg = false

---@param opts snacks.notifier.Notif.opts
function N:add(opts)
  if opts.checkhealth then
    health_msg = true
    return
  end
  local now = ts()
  local notif = vim.deepcopy(opts) --[[@as snacks.notifier.Notif]]
  notif.msg = notif.msg or ""

  -- NOTE: support nvim-notify style replace
  ---@diagnostic disable-next-line: undefined-field
  if not notif.id and notif.replace then
    ---@diagnostic disable-next-line: undefined-field
    notif.id = type(notif.replace) == "table" and notif.replace.id or notif.replace
  end

  notif.title = (notif.title or ""):gsub("\n", " ")
  notif.id = notif.id or next_id()
  notif.level = normlevel(notif.level)
  notif.icon = notif.icon or self.opts.icons[notif.level]
  notif.timeout = notif.timeout == false and 0 or notif.timeout
  notif.timeout = notif.timeout == true and self.opts.timeout or notif.timeout
  notif.timeout = notif.timeout or self.opts.timeout
  notif.added = now

  if opts.id and self.queue[opts.id] then
    local n = self.queue[opts.id] --[[@as snacks.notifier.Notif]]
    notif.added = n.added
    notif.updated = now
    notif.shown = n.shown and now or nil -- reset shown time
    notif.win = n.win
    notif.layout = n.layout
    notif.dirty = true
  end
  if opts.history ~= false then
    self.history[notif.id] = notif
  end
  self.sorted = nil
  local want = numlevel(notif.level) >= numlevel(self.opts.level)
  want = want and (not self.opts.filter or self.opts.filter(notif))
  if not want then
    return notif.id
  end
  self.queue[notif.id] = notif
  if self:is_blocking() then
    pcall(function()
      self:process()
    end)
  end
  return notif.id
end

function N:update()
  local now = ts()
  --- Cleanup queue
  for id, notif in pairs(self.queue) do
    local timeout = notif.timeout or self.opts.timeout
    local keep = not notif.shown -- not shown yet
      or timeout == 0 -- no timeout
      or (notif.win and notif.win:win_valid() and vim.api.nvim_get_current_win() == notif.win.win) -- current window
      or (notif.win and notif.win:buf_valid() and vim.api.nvim_get_current_buf() == notif.win.buf) -- current buffer
      or (notif.keep and notif.keep(notif)) -- custom keep
      or (self.opts.keep and self.opts.keep(notif)) -- global keep
      or (notif.shown + timeout / 1e3 > now) -- not timed out
    if not keep then
      self:hide(id)
    end
  end
  self.sorted = self.sorted or self:sort()
end

---@param opts? snacks.notifier.history
---@return snacks.notifier.Notif[]
function N:get_history(opts)
  ---@type snacks.notifier.history
  opts = vim.tbl_deep_extend("force", {}, history_opts, opts or {})
  local notifs = vim.tbl_values(self.history)
  local filter = opts.filter
  if type(filter) == "string" or type(filter) == "number" then
    local level = numlevel(filter)
    filter = function(n)
      return numlevel(n.level) >= level
    end
  end
  notifs = filter and vim.tbl_filter(filter, notifs) or notifs
  local ret = self:sort(notifs, opts.sort)
  if opts.reverse then
    local rev = {}
    for i = #ret, 1, -1 do
      table.insert(rev, ret[i])
    end
    ret = rev
  end
  return ret
end

---@param opts? snacks.notifier.history
function N:show_history(opts)
  if vim.bo.filetype == "snacks_notif_history" then
    vim.cmd("close")
    return
  end
  local win = Snacks.win({ style = "notification_history", enter = true, show = false })
  local buf = win:open_buf()
  opts = opts or {}
  if opts.reverse == nil then
    opts.reverse = true
  end
  for _, notif in ipairs(self:get_history(opts)) do
    N.styles.history(buf, notif, {
      opts = win.opts,
      notifier = self,
      ns = N.ns,
      hl = self:hl(notif),
    })
  end
  return win:show()
end

---@param id? number|string
function N:hide(id)
  if not id then
    for i in pairs(self.queue) do
      self:hide(i)
    end
    return
  end
  local notif = self.queue[id]
  if not notif then
    return
  end
  self.queue[id], self.sorted = nil, nil
  notif.hidden = ts()
  if notif.win then
    notif.win:close()
    notif.win = nil
  end
end

---@param value number
---@param min number
---@param max number
---@param parent number
local function dim(value, min, max, parent)
  min = math.floor(min < 1 and (parent * min) or min)
  max = math.floor(max < 1 and (parent * max) or max)
  return math.min(max, math.max(min, value))
end

---@param style? snacks.notifier.style
---@return snacks.notifier.render
function N:get_render(style)
  style = style or self.opts.style
  return type(style) == "function" and style or N.styles[style] or N.styles.compact
end

---@param notif snacks.notifier.Notif
function N:hl(notif)
  ---@type snacks.notifier.hl
  return vim.tbl_extend("force", {
    title = hl("Title", notif.level),
    icon = hl("Icon", notif.level),
    border = hl("Border", notif.level),
    footer = hl("Footer", notif.level),
    msg = hl("", notif.level),
  }, notif.hl or {})
end

---@param notif snacks.notifier.Notif
function N:render(notif)
  if type(notif.opts) == "function" then
    notif.opts(notif)
  end

  ---@type snacks.notifier.hl
  local notif_hl = self:hl(notif)

  local win = notif.win
    or Snacks.win({
      show = false,
      style = "notification",
      enter = false,
      backdrop = false,
      ft = notif.ft,
      noautocmd = true,
      keys = {
        q = function()
          self:hide(notif.id)
        end,
      },
    })
  win.opts.wo.winhighlight = table.concat({
    "Normal:" .. notif_hl.msg,
    "NormalNC:" .. notif_hl.msg,
    "FloatBorder:" .. notif_hl.border,
    "FloatTitle:" .. notif_hl.title,
    "FloatFooter:" .. notif_hl.footer,
  }, ",")
  notif.win = win
  ---@diagnostic disable-next-line: invisible
  local buf = win:open_buf()
  vim.api.nvim_buf_clear_namespace(buf, N.ns, 0, -1)
  local render = self:get_render(notif.style)

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
  render(buf, notif, {
    opts = win.opts,
    notifier = self,
    ns = N.ns,
    hl = notif_hl,
  })
  vim.bo[buf].modifiable = false

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  -- for the minimal style, we also have to factor in the icon width
  local icon_width = self.opts.style == "minimal" and vim.api.nvim_strwidth(notif.icon) or 0
  local pad = (self.opts.padding and (win:add_padding() or 2) or 0) + icon_width
  local width = win:border_text_width()
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line) + pad)
  end
  width = dim(width, self.opts.width.min, self.opts.width.max, vim.o.columns)

  local height = #lines
  -- calculate wrapped height
  if win.opts.wo.wrap then
    height = 0
    for _, line in ipairs(lines) do
      height = height + math.ceil((vim.fn.strdisplaywidth(line) + pad) / width)
    end
  end
  local wanted_height = height
  height = dim(height, self.opts.height.min, self.opts.height.max, vim.o.lines)

  if wanted_height > height and win:has_border() and self.opts.more_format and not win.opts.footer then
    win.opts.footer = self.opts.more_format:format(wanted_height - height)
    win.opts.footer_pos = "right"
  end

  win.opts.width = width
  win.opts.height = height
end

---@param notifs? snacks.notifier.Notif[]
---@param fields? string[]
function N:sort(notifs, fields)
  fields = fields or self.opts.sort
  notifs = notifs or vim.tbl_values(self.queue)
  table.sort(notifs, function(a, b)
    for _, key in ipairs(fields) do
      local function v(n)
        if key == "level" then
          return 10 - numlevel(n[key])
        end
        return n[key]
      end
      local av, bv = v(a), v(b)
      if av ~= bv then
        return av < bv
      end
    end
    return false
  end)
  return notifs
end

function N:new_layout()
  ---@class snacks.notifier.layout
  local layout = {}
  layout.free = 0
  layout.rows = {} ---@type boolean[]
  ---@param row number
  ---@param height number
  ---@param free boolean
  function layout.mark(row, height, free)
    for i = row, math.min(row + height - 1, vim.o.lines) do
      layout.free = layout.free + (free and 1 or -1)
      layout.rows[i] = free
    end
  end
  ---@param height number
  ---@param row? number wanted row
  function layout.find(height, row)
    local from, to, down = row or 1, vim.o.lines - height, self.opts.top_down
    for i = down and from or to, down and to or from, down and 1 or -1 do
      local ret = true
      for j = i, i + height - 1 do
        if not layout.rows[j] then
          ret = false
          break
        end
      end
      if ret then
        return i
      end
    end
  end
  layout.mark(1, vim.o.lines, true)
  layout.mark(1, self.opts.margin.top + (vim.o.tabline == "" and 0 or 1), false)
  layout.mark(vim.o.lines - (self.opts.margin.bottom + (vim.o.laststatus == 0 and 0 or 1)) + 1, vim.o.lines, false)
  return layout
end

function N:layout()
  local layout = self:new_layout()
  local wins_updated = 0
  local wins_created = 0
  local update = {} ---@type snacks.win[]
  for _, notif in ipairs(assert(self.sorted)) do
    if layout.free < (self.opts.height.min + 2) then -- not enough space
      if notif.win then
        notif.shown = nil
        notif.win:hide()
      end
    else
      local prev_layout = notif.layout
        and { top = notif.layout.top, height = notif.layout.height, width = notif.layout.width }
      if not notif.win or notif.dirty or not notif.win:buf_valid() or type(notif.opts) == "function" then
        notif.dirty = true
        self:render(notif)
        notif.dirty = false
        notif.layout = notif.win:size()
        notif.layout.top = prev_layout and prev_layout.top
        prev_layout = nil -- always re-render since opts might've changed
      end
      notif.layout.top = layout.find(notif.layout.height, notif.layout.top)
      if notif.layout.top then
        layout.mark(notif.layout.top, notif.layout.height, false)
        if not vim.deep_equal(prev_layout, notif.layout) then
          if notif.win:win_valid() then
            wins_updated = wins_updated + 1
          else
            wins_created = wins_created + 1
          end
          update[#update + 1] = notif.win
          notif.win.opts.row = notif.layout.top - 1
          notif.win.opts.col = vim.o.columns - notif.layout.width - self.opts.margin.right
          notif.shown = notif.shown or ts()
          notif.win:show()
        end
      elseif notif.win then
        notif.shown = nil
        notif.win:hide()
      end
    end
  end

  if #update > 0 and not self.in_search() then
    if vim.api.nvim__redraw then
      for _, win in ipairs(update) do
        win:redraw()
      end
    else
      vim.cmd.redraw()
    end
  end
end

function N.in_search()
  return vim.tbl_contains({ "/", "?" }, vim.fn.getcmdtype())
end

---@param msg string
---@param level? snacks.notifier.level|number
---@param opts? snacks.notifier.Notif.opts
function N:notify(msg, level, opts)
  opts = opts or {}
  opts.msg = msg
  opts.level = level
  return self:add(opts)
end

-- Global instance
local notifier = N.new()

---@param msg string
---@param level? snacks.notifier.level|number
---@param opts? snacks.notifier.Notif.opts
function M.notify(msg, level, opts)
  return notifier:notify(msg, level, opts)
end

---@param id? number|string
function M.hide(id)
  return notifier:hide(id)
end

---@param opts? snacks.notifier.history
function M.get_history(opts)
  return notifier:get_history(opts)
end

---@param opts? snacks.notifier.history
function M.show_history(opts)
  return notifier:show_history(opts)
end

---@private
function M.health()
  health_msg = false
  vim.notify("", nil, { checkhealth = true })
  vim.wait(500, function()
    return health_msg
  end, 10)
  if health_msg then
    Snacks.health.ok("is ready")
  else
    Snacks.health.error("is not ready")
  end
end

return M
