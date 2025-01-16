local Async = require("snacks.picker.util.async")

---@class snacks.picker.Finder
---@field _find snacks.picker.finder
---@field task snacks.picker.Async
---@field items snacks.picker.finder.Item[]
---@field filter? snacks.picker.Filter
local M = {}
M.__index = M

---@alias snacks.picker.finder fun(opts:snacks.picker.Config, filter:snacks.picker.Filter): (snacks.picker.finder.Item[] | fun(cb:async fun(item:snacks.picker.finder.Item)))
---@alias snacks.picker.finder.multi (snacks.picker.finder|string)[]

local YIELD_FIND = 1 -- ms

---@param find snacks.picker.finder
function M.new(find)
  local self = setmetatable({}, M)
  self._find = find
  self.task = Async.nop()
  self.items = {}
  return self
end

function M:running()
  return self.task:running()
end

function M:abort()
  self.task:abort()
end

function M:count()
  return #self.items
end

---@param search string
function M:changed(search)
  search = vim.trim(search)
  return not self.filter or self.filter.search ~= search
end

---@param picker snacks.Picker
function M:run(picker)
  local default_score = require("snacks.picker.core.matcher").DEFAULT_SCORE
  self.task:abort()
  self.items = {}
  local yield ---@type fun()
  self.filter = picker.input.filter:clone({ trim = true })
  local finder = self._find(picker.opts, self.filter)
  local limit = picker.opts.limit or math.huge

  ---@param item snacks.picker.finder.Item
  local function add(item)
    item.idx, item.score = #self.items + 1, default_score
    self.items[item.idx] = item
  end

  -- PERF: if finder is a table, we can skip the async part
  if type(finder) == "table" then
    local items = finder --[[@as snacks.picker.finder.Item[] ]]
    for _, item in ipairs(items) do
      add(item)
    end
    return
  end

  collectgarbage("stop") -- moar speed
  ---@cast finder fun(cb:async fun(item:snacks.picker.finder.Item))
  ---@diagnostic disable-next-line: await-in-sync
  self.task = Async.new(function()
    ---@async
    finder(function(item)
      if #self.items >= limit then
        self.task:abort()
        if coroutine.running() then
          Async.yield()
        end
        return
      end
      add(item)
      picker.matcher.task:resume()
      yield = yield or Async.yielder(YIELD_FIND)
      yield()
    end)
  end):on("done", function()
    collectgarbage("restart")
    picker.matcher.task:resume()
    picker:update()
  end)
end

---@param finders snacks.picker.finder[]
---@return snacks.picker.finder
function M.multi(finders)
  return function(opts, filter)
    ---@type fun(cb:async fun(item:snacks.picker.finder.Item))[]
    local running = {}
    local items = {} ---@type snacks.picker.finder.Item[]
    for _, finder in ipairs(finders) do
      local find = finder(opts, filter)
      if type(find) == "table" then
        vim.list_extend(items, find)
      else
        running[#running + 1] = find
      end
    end
    return #running == 0 and items
      or function(cb)
        for _, item in ipairs(items) do
          cb(item)
        end
        items = {} -- release memory
        for _, find in ipairs(running) do
          find(cb)
        end
      end
  end
end

return M
