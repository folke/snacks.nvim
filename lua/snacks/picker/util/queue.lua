--- Efficient queue implementation.
--- Prevents need to shift elements when popping.
---@class snacks.picker.queue
---@field queue any[]
---@field first number
---@field last number
local M = {}
M.__index = M

function M.new()
  local self = setmetatable({}, M)
  self.first, self.last, self.queue = 0, -1, {}
  return self
end

function M:push(value)
  self.last = self.last + 1
  self.queue[self.last] = value
end

function M:size()
  return self.last - self.first + 1
end

function M:empty()
  return self:size() == 0
end

function M:pop()
  if self:empty() then
    return
  end
  local value = self.queue[self.first]
  self.queue[self.first] = nil
  self.first = self.first + 1
  return value
end

return M
