---@class snacks.picker.MinHeap
---@field data any[]          -- the heap array
---@field cmp fun(a:any, b:any):boolean  -- determines "priority"; if cmp(a,b) == true, a is considered 'larger' for top-k
---@field capacity number
---@field sorted? snacks.picker.Item[]
local M = {}
M.__index = M

---@class snacks.picker.minheap.Config
---@field cmp? fun(a, b):boolean
---@field capacity number

---@param opts? snacks.picker.minheap.Config
function M.new(opts)
  opts = opts or {}
  local self = setmetatable({}, M)

  -- Default comparator means: a > b => a is 'better' (we want the top by value)
  -- So if we want the top K largest items, the heap is min-heap based on that comparator
  self.cmp = opts.cmp or function(a, b)
    return a > b
  end
  self.capacity = assert(opts.capacity, "capacity is required")
  assert(self.capacity > 0, "capacity must be greater than 0")
  self.data = {}
  return self
end

function M:clear()
  self.data = {}
  self.sorted = nil
end

-- Private: swap two indices
function M:_swap(i, j)
  self.data[i], self.data[j] = self.data[j], self.data[i]
end

-- Private: heapify up (bubble up)
function M:_heapify_up(idx)
  while idx > 1 do
    local parent = math.floor(idx / 2)
    -- If child is 'less' than parent under the min-heap logic, swap
    -- Because self.cmp(child, parent) == true => child is 'bigger' => for min-heap we want bigger below
    -- So we invert self.cmp because we want to keep the smallest at top:
    if self.cmp(self.data[parent], self.data[idx]) then
      self:_swap(parent, idx)
      idx = parent
    else
      break
    end
  end
end

-- Private: heapify down
function M:_heapify_down(idx)
  local size = #self.data
  while true do
    local left = 2 * idx
    local right = left + 1
    local smallest = idx

    if left <= size and self.cmp(self.data[smallest], self.data[left]) then
      smallest = left
    end
    if right <= size and self.cmp(self.data[smallest], self.data[right]) then
      smallest = right
    end
    if smallest ~= idx then
      self:_swap(idx, smallest)
      idx = smallest
    else
      break
    end
  end
end

--- Insert value into the min-heap of capacity K.
--- If the heap is not full, just insert.
--- If it's full and the value is 'larger' than the min (root), replace the root & heapify.
---@generic T
---@param value T
---@return boolean added, T? evicted
function M:add(value)
  local size = #self.data
  if size < self.capacity then
    -- Just insert at the end, heapify up
    table.insert(self.data, value)
    self:_heapify_up(#self.data)
    self.sorted = nil
    return true
  else
    -- If new value is larger than the root (which is the smallest in the min-heap),
    -- then pop root & insert new value
    if self.cmp(value, self.data[1]) then
      local evicted = self.data[1]
      self.data[1] = value
      self:_heapify_down(1)
      self.sorted = nil
      return true, evicted
    end
  end
  return false
end

function M:count()
  return #self.data
end

---@return any|nil
function M:min()
  return self.data[1]
end

---@return any|nil
function M:max()
  -- might need to scan if you want the max element in a min-heap
  local size = #self.data
  if size == 0 then
    return nil
  end
  local maximum = self.data[1]
  for i = 2, size do
    if self.cmp(self.data[i], maximum) then
      maximum = self.data[i]
    end
  end
  return maximum
end

---@param idx number
---@return snacks.picker.Item?
---@overload fun(self: snacks.picker.MinHeap): snacks.picker.Item[]
function M:get(idx)
  if not self.sorted then
    self.sorted = {}
    for i = 1, #self.data do
      table.insert(self.sorted, self.data[i])
    end
    table.sort(self.sorted, self.cmp)
  end
  if idx then
    return self.sorted[idx]
  end
  return self.sorted
end

return M
