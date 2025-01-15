---@class snacks.picker.Filter
---@field pattern string Pattern used to filter items by the matcher
---@field search string Initial search string used by finders
---@field buf? number
---@field file? string
---@field cwd string
---@field all boolean
---@field paths {path:string, want:boolean}[]
---@field opts snacks.picker.filter.Config
local M = {}
M.__index = M

local uv = vim.uv or vim.loop

---@param picker snacks.Picker
function M.new(picker)
  local opts = picker.opts ---@type snacks.picker.Config|{filter?:snacks.picker.filter.Config}
  local self = setmetatable({}, M)
  self.opts = opts.filter or {}
  local function gets(v)
    return type(v) == "function" and v(picker) or v or "" --[[@as string]]
  end
  self.pattern = gets(opts.pattern)
  self.search = gets(opts.search)
  local filter = opts.filter
  self.all = not filter or not (filter.cwd or filter.buf or filter.paths or filter.filter)
  self.paths = {}
  local cwd = filter and filter.cwd
  self.cwd = type(cwd) == "string" and cwd or opts.cwd or uv.cwd() or "."
  self.cwd = vim.fs.normalize(self.cwd --[[@as string]], { _fast = true })
  if not self.all and filter then
    self.buf = filter.buf == true and 0 or filter.buf --[[@as number?]]
    self.buf = self.buf == 0 and vim.api.nvim_get_current_buf() or self.buf
    self.file = self.buf and vim.fs.normalize(vim.api.nvim_buf_get_name(self.buf), { _fast = true }) or nil
    for path, want in pairs(filter.paths or {}) do
      table.insert(filter, { path = vim.fs.normalize(path), want = want })
    end
  end
  return self
end

---@param opts? {trim?:boolean}
---@return snacks.picker.Filter
function M:clone(opts)
  local ret = setmetatable({}, { __index = self })
  if opts and opts.trim then
    ret.pattern = vim.trim(self.pattern)
    ret.search = vim.trim(self.search)
  else
    ret.pattern = self.pattern
    ret.search = self.search
  end
  return ret
end

---@param item snacks.picker.finder.Item):boolean
function M:match(item)
  if self.all then
    return true
  end
  if self.opts.filter and not self.opts.filter(item) then
    return false
  end
  if self.buf and (item.buf ~= self.buf) and (item.file ~= self.file) then
    return false
  end
  if not (self.opts.cwd or self.opts.paths) then
    return true
  end
  local path = Snacks.picker.util.path(item)
  if not path then
    return false
  end
  if self.opts.cwd and path:sub(1, #self.cwd) ~= self.cwd then
    return false
  end
  if self.opts.paths then
    for _, p in ipairs(self.paths) do
      if (path:sub(1, #p.path) == p.path) ~= p.want then
        return false
      end
    end
  end
  return true
end

---@param items snacks.picker.finder.Item[]
function M:filter(items)
  if self.all then
    return items
  end
  local ret = {} ---@type snacks.picker.finder.Item[]
  for _, item in ipairs(items) do
    if self:match(item) then
      table.insert(ret, item)
    end
  end
  return ret
end

return M
