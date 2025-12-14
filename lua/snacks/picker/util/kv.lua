---@class snacks.picker.KeyValue
---@field data table<string, number>
---@field loaded_time number
---@field path string
---@field max_size number
---@field cmp fun(a:snacks.picker.KeyValue.entry, b:snacks.picker.KeyValue.entry): boolean
local M = {}
M.__index = M
local uv = vim.uv or vim.loop

---@alias snacks.picker.KeyValue.entry {key:string, value:number}

---@param path string
---@param opts? {max_size?: number, cmp?: fun(a:snacks.picker.KeyValue.entry, b:snacks.picker.KeyValue.entry): boolean}
function M.new(path, opts)
  local self = setmetatable({}, M)
  self.data = {}
  self.path = path
  self.max_size = opts and opts.max_size or 10000
  ---@param a snacks.picker.KeyValue.entry
  ---@param b snacks.picker.KeyValue.entry
  self.cmp = opts and opts.cmp or function(a, b)
    return a.value > b.value
  end
  self.loaded_time = os.time()
  local fd = io.open(path, "rb")
  if fd then
    ---@type string
    local data = fd:read("*a")
    fd:close()
    local ok, decoded = pcall(require("string.buffer").decode, data)
    self.data = ok and decoded or {} --[[@as table<string, number>]]
  end
  return self
end

function M:set(key, value)
  self.data[key] = value
end

function M:get(key)
  return self.data[key]
end

function M:get_all()
  return self.data
end

function M:close()
  vim.fn.mkdir(vim.fn.fnamemodify(self.path, ":h"), "p")
  local stat = uv.fs_stat(self.path)
  -- check if the file was modified since we loaded it
  if self.loaded_time > 0 and stat and stat.mtime.sec > self.loaded_time then
    return
  end
  local entries = {} ---@type snacks.picker.KeyValue.entry[]
  for k, v in pairs(self.data) do
    table.insert(entries, { key = k, value = v })
  end
  table.sort(entries, self.cmp)

  self.data = {}
  for i = 1, math.min(#entries, self.max_size) do
    local entry = entries[i]
    self.data[entry.key] = entry.value
  end
  local data = require("string.buffer").encode(self.data)
  local fd = io.open(self.path, "w+b")
  if not fd then
    return
  end
  fd:write(data)
  fd:close()
end

return M
