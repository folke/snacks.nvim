---@class snacks.layout
---@field opts snacks.layout.Config
---@field root snacks.win
---@field wins table<string, snacks.win|{enabled?:boolean}>
---@field box_wins snacks.win[]
---@field win_opts table<string, snacks.win.Config>
---@field closed? boolean
local M = {}
M.__index = M

M.meta = {
  desc = "Window layouts",
}

---@class snacks.layout.Win: snacks.win.Config,{}
---@field depth? number
---@field win string layout window name

---@class snacks.layout.Box: snacks.layout.Win,{}
---@field box "horizontal" | "vertical"
---@field id? number
---@field [number] snacks.layout.Win | snacks.layout.Box children

---@alias snacks.layout.Widget snacks.layout.Win | snacks.layout.Box

---@class snacks.layout.Config
---@field show? boolean show the layout on creation (default: true)
---@field wins table<string, snacks.win> windows to include in the layout
---@field layout snacks.layout.Box layout definition
---@field fullscreen? boolean open in fullscreen
---@field hidden? string[] list of windows that will be excluded from the layout (but can be toggled)
---@field on_update? fun(layout: snacks.layout)
local defaults = {
  layout = {
    width = 0.6,
    height = 0.6,
    zindex = 50,
  },
}

---@param opts snacks.layout.Config
function M.new(opts)
  local self = setmetatable({}, M)
  self.opts = vim.tbl_extend("force", defaults, opts)
  self.win_opts = {}
  self.wins = self.opts.wins or {}
  self.box_wins = {}

  -- assign ids to boxes and create box wins if needed
  local id = 1
  self:each(function(box, parent)
    box.depth = (parent and parent.depth + 1) or 0
    if box.box then
      ---@cast box snacks.layout.Box
      box.id, id = id, id + 1
      local has_border = box.border and box.border ~= "" and box.border ~= "none"
      local is_root = box.id == 1
      if is_root or has_border then
        local backdrop = false ---@type boolean?
        if is_root then
          backdrop = nil
        end
        self.box_wins[box.id] = Snacks.win(Snacks.win.resolve(box, {
          relative = is_root and (box.relative or "editor") or "win",
          focusable = false,
          enter = false,
          show = false,
          resize = false,
          noautocmd = true,
          backdrop = backdrop,
          zindex = (self.opts.layout.zindex or 50) + box.depth,
          bo = { filetype = "snacks_layout_box" },
          border = box.border,
        }))
      end
    end
  end)
  self.root = self.box_wins[1]
  assert(self.root, "no root box found")

  for w, win in pairs(self.wins) do
    self.win_opts[w] = vim.deepcopy(win.opts)
  end

  -- close layout when any win is closed
  self.root:on("WinClosed", function(_, ev)
    if self.closed then
      return true
    end
    local wid = tonumber(ev.match)
    for _, win in pairs(self:get_wins()) do
      if win.win == wid then
        self:close()
        return true
      end
    end
  end)

  -- update layout on VimResized
  self.root:on("VimResized", function()
    self:update()
  end)
  if self.opts.show ~= false then
    vim.schedule(function()
      self:show()
    end)
  end
  return self
end

---@param cb fun(widget: snacks.layout.Widget, parent?: snacks.layout.Box)
---@param opts? {wins?:boolean, boxes?:boolean, box?:snacks.layout.Box}
function M:each(cb, opts)
  opts = opts or {}
  ---@param widget snacks.layout.Widget
  ---@param parent? snacks.layout.Box
  local function _each(widget, parent)
    if widget.box then
      if opts.boxes ~= false then
        cb(widget, parent)
      end
      ---@cast widget snacks.layout.Box
      for _, child in ipairs(widget) do
        _each(child, widget)
      end
    elseif opts.wins ~= false then
      cb(widget, parent)
    end
  end
  _each(opts.box or self.opts.layout)
end

--- Check if a window is hidden
---@param win string
function M:is_hidden(win)
  return self.opts.hidden and vim.tbl_contains(self.opts.hidden, win)
end

--- Toggle a window
---@param win string
function M:toggle(win)
  self.opts.hidden = self.opts.hidden or {}
  if self:is_hidden(win) then
    self.opts.hidden = vim.tbl_filter(function(w)
      return w ~= win
    end, self.opts.hidden)
  else
    table.insert(self.opts.hidden, win)
  end
  self:update()
end

---@package
function M:update()
  if self.closed then
    return
  end
  vim.o.lazyredraw = true
  for _, win in pairs(self.wins) do
    win.enabled = false
  end
  local layout = vim.deepcopy(self.opts.layout)
  if self.opts.fullscreen then
    layout.width = 0
    layout.height = 0
    layout.col = 0
    layout.row = 0
  end
  if not self.root:valid() then
    self.root:show()
  end
  self:update_box(layout, {
    col = 0,
    row = 0,
    width = vim.o.columns,
    height = vim.o.lines,
  })

  for _, win in pairs(self:get_wins()) do
    if win:valid() then
      -- update windows with eventignore=all
      -- to fix issues with syntax being reset
      local ei = vim.o.eventignore
      vim.o.eventignore = "all"
      win:update()
      vim.o.eventignore = ei
    else
      win:show()
    end
  end
  for w, win in pairs(self.wins) do
    if not self:is_enabled(w) and win:win_valid() then
      win:close()
    end
  end
  if self.opts.on_update then
    self.opts.on_update(self)
  end
  vim.o.lazyredraw = false
end

---@param box snacks.layout.Box
---@param parent snacks.win.Dim
---@private
function M:update_box(box, parent)
  local size_main = box.box == "horizontal" and "width" or "height"
  local pos_main = box.box == "horizontal" and "col" or "row"
  local is_root = box.id == 1

  if not is_root then
    box.col = box.col or 0
    box.row = box.row or 0
  end

  local children = {} ---@type snacks.layout.Widget[]
  for c, child in ipairs(box) do
    if not (child.win and self:is_hidden(child.win)) then
      children[#children + 1] = child
    end
    box[c] = nil
  end
  for c, child in ipairs(children) do
    box[c] = child
  end

  local dim, border = self:dim_box(box, parent)
  local orig_dim = vim.deepcopy(dim)
  if is_root then
    dim.col = 0
    dim.row = 0
  else
    dim.col = dim.col + border.left
    dim.row = dim.row + border.top
  end
  local free = vim.deepcopy(dim)

  local function size(child)
    return child[size_main] or 0
  end

  local dims = {} ---@type table<number, snacks.win.Dim>
  local flex = 0
  for c, child in ipairs(box) do
    flex = flex + (size(child) == 0 and 1 or 0)
    if size(child) > 0 then
      dims[c] = self:resolve(child, dim)
      free[size_main] = free[size_main] - dims[c][size_main]
    end
  end
  local free_main = free[size_main]
  for c, child in ipairs(box) do
    if size(child) == 0 then
      free[size_main] = math.floor(free_main / flex)
      flex = flex - 1
      free_main = free_main - free[size_main]
      dims[c] = self:resolve(child, free)
    end
  end
  -- assert(free[size_main] >= 0, "not enough space for children")
  -- fix positions
  local offset = 0
  for c, child in ipairs(box) do
    local wins = self:get_wins(child)
    for _, win in ipairs(wins) do
      win.opts[pos_main] = win.opts[pos_main] + offset
    end
    offset = offset + dims[c][size_main]
  end

  dim.width = dim.width + border.left + border.right
  dim.height = dim.height + border.top + border.bottom

  local box_win = self.box_wins[box.id]
  if box_win then
    if not is_root then
      box_win.opts.win = self.root.win
    end
    box_win.opts.col = orig_dim.col
    box_win.opts.row = orig_dim.row
    box_win.opts.width = orig_dim.width
    box_win.opts.height = orig_dim.height
  end

  return dim
end

---@param widget? snacks.layout.Widget
---@package
function M:get_wins(widget)
  local ret = {} ---@type snacks.win[]
  self:each(function(w)
    if w.box and self.box_wins[w.id] then
      table.insert(ret, self.box_wins[w.id])
    elseif w.win and self:is_enabled(w.win) then
      table.insert(ret, self.wins[w.win])
    end
  end, { box = widget })
  return ret
end

---@param widget snacks.layout.Widget
---@param parent snacks.win.Dim
---@private
function M:resolve(widget, parent)
  if widget.box then
    ---@cast widget snacks.layout.Box
    return self:update_box(widget, parent)
  else
    assert(widget.win, "widget must have win or box")
    ---@cast widget snacks.layout.Win
    return self:update_win(widget, parent)
  end
end

---@param widget snacks.layout.Box
---@param parent snacks.win.Dim
---@private
function M:dim_box(widget, parent)
  local opts = vim.deepcopy(widget) --[[@as snacks.win.Config]]
  -- adjust max width / height
  opts.max_width = math.min(parent.width, opts.max_width or parent.width)
  opts.max_height = math.min(parent.height, opts.max_height or parent.height)
  local fake_win = setmetatable({ opts = opts }, Snacks.win)
  local ret = fake_win:dim(parent)
  return ret, fake_win:border_size()
end

---@param win snacks.layout.Win
---@param parent snacks.win.Dim
---@private
function M:update_win(win, parent)
  local w = self.wins[win.win]
  w.enabled = true
  assert(w, ("win %s not part of layout"):format(win.win))
  -- add win opts from layout
  w.opts = vim.tbl_extend(
    "force",
    vim.deepcopy(self.win_opts[win.win] or {}),
    {
      width = 0,
      height = 0,
      enter = false,
    },
    win,
    {
      relative = "win",
      win = self.root.win,
      backdrop = false,
      resize = false,
      zindex = self.root.opts.zindex + win.depth,
    }
  )
  -- adjust max width / height
  w.opts.max_width = math.min(parent.width, w.opts.max_width or parent.width)
  w.opts.max_height = math.min(parent.height, w.opts.max_height or parent.height)
  -- resolve width / height relative to parent box
  local dim = w:dim(parent)
  w.opts.width, w.opts.height = dim.width, dim.height
  local border = w:border_size()
  w.opts.col, w.opts.row = parent.col, parent.row
  dim.width = dim.width + border.left + border.right
  dim.height = dim.height + border.top + border.bottom
  -- dim.col = dim.col + border.left
  -- dim.row = dim.row + border.top
  return dim
end

--- Toggle fullscreen
function M:maximize()
  self.opts.fullscreen = not self.opts.fullscreen
  self:update()
end

--- Close the layout
---@param opts? {wins?: boolean}
function M:close(opts)
  if self.closed then
    return
  end
  opts = opts or {}
  self.closed = true
  for w, win in pairs(self.wins) do
    if opts.wins == false then
      win.opts = self.win_opts[w]
    elseif win:valid() then
      win:close()
    end
  end
  for _, win in pairs(self.box_wins) do
    win:close()
  end
end

--- Check if layout is valid (visible)
function M:valid()
  return self.root:valid()
end

--- Check if the window has been used in the layout
---@param w string
function M:is_enabled(w)
  return not self:is_hidden(w) and self.wins[w].enabled
end

--- Show the layout
function M:show()
  if self:valid() then
    return
  end
  self:update()
end

return M
