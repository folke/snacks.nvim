local Async = require("snacks.picker.util.async")

---@class snacks.picker.Finder
---@field _find snacks.picker.finder
---@field task snacks.picker.Async
---@field items snacks.picker.finder.Item[]
---@field filter? snacks.picker.Filter
local M = {}
M.__index = M

---@class snacks.picker.finder.ctx
---@field picker snacks.Picker
---@field filter snacks.picker.Filter
---@field async snacks.picker.Async
---@field meta table<string, any>

---@alias snacks.picker.finder.async fun(cb:async fun(item:snacks.picker.finder.Item))
---@alias snacks.picker.finder.result snacks.picker.finder.Item[] | snacks.picker.finder.async
---@alias snacks.picker.finder fun(opts: snacks.picker.Config, ctx: snacks.picker.finder.ctx): snacks.picker.finder.result
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

function M:close()
  self.task:abort()
  self.task = Async.nop()
  self._find = function()
    return {}
  end
end

---@param picker snacks.Picker
function M:ctx(picker)
  local notified = false
  ---@type snacks.picker.finder.ctx
  local ret = {
    picker = picker,
    async = setmetatable({}, {
      __index = function()
        if not notified then
          notified = true
          Snacks.notify.warn("You can only use the `async` object in async functions")
        end
      end,
    }),
    filter = self.filter,
    meta = {},
  }
  setmetatable(ret, { __index = M:deprecated(self.filter) })
  return ret
end

---@param filter snacks.picker.Filter
---@return boolean changed
function M:init(filter)
  local ret = not (self.filter and (self.filter.search == filter.search and self.filter.source_id == filter.source_id))
  self.filter = filter
  return ret
end

---@generic T: table
---@param t T
---@return T
function M:deprecated(t)
  local notified = false
  return setmetatable({}, {
    __index = function(_, k)
      if not notified then
        notified = true
        Snacks.notify.warn({
          "# API changed",
          "",
          "- Snacks finder signature changed.",
          "```lua",
          "fun(opts: snacks.picker.Config, ctx: snacks.picker.finder.ctx)",
          "```",
        })
        Snacks.debug.backtrace()
      end
      return t[k]
    end,
  })
end

---@param picker snacks.Picker
function M:run(picker)
  local default_score = require("snacks.picker.core.matcher").DEFAULT_SCORE
  self.task:abort()
  self.items = {}
  local yield ---@type fun()
  local ctx = self:ctx(picker)
  local finder = self._find(picker.opts, ctx, self:deprecated(picker))
  local limit = (picker.opts.live and picker.opts.limit_live or picker.opts.limit) or math.huge

  ---@param item snacks.picker.finder.Item
  local function add(item)
    item.idx, item.score = #self.items + 1, default_score
    self.items[item.idx] = item
  end

  if picker.opts.transform then
    local transform = Snacks.picker.config.transform(picker.opts)
    ---@param item snacks.picker.finder.Item
    function add(item)
      local t = transform(item, ctx)
      item = type(t) == "table" and t or item
      if t ~= false then
        item.idx, item.score = #self.items + 1, default_score
        self.items[item.idx] = item
      end
    end
  end

  -- PERF: if finder is a table, we can skip the async part
  if type(finder) == "table" then
    local items = finder --[[@as snacks.picker.finder.Item[] ]]
    for _, item in ipairs(items) do
      add(item)
    end
    return
  end

  local running = true

  collectgarbage("stop") -- moar speed
  ---@cast finder snacks.picker.finder.async
  ---@diagnostic disable-next-line: await-in-sync
  self.task = Async.new(function()
    ctx.async = Async.running()
    ---@async
    finder(function(item)
      if #self.items >= limit then
        return self.task:abort()
      end
      if not running then
        Snacks.debug.backtrace({
          "Finder yielded after done. This is a bug.",
          ("- aborted: `%s`"):format(self.task:aborted() or false),
          "",
          "# Backtrace",
        }, {
          level = vim.log.levels.ERROR,
          title = "Snacks Picker Finder",
        })
        return
      end
      add(item)
      picker.matcher.task:resume()
      yield = yield or Async.yielder(YIELD_FIND)
      yield()
    end, self:deprecated(ctx.async))
  end):on("done", function()
    collectgarbage("restart")
    if not self.task:aborted() then
      picker.matcher.task:resume()
      picker:update()
    end
    running = false
  end)
end

---@param finders snacks.picker.finder[]
---@return snacks.picker.finder
function M.multi(finders)
  return function(opts, ctx)
    local filter = ctx.filter
    ---@type snacks.picker.finder.result[]
    local results = {}
    local need_async = false
    for source_id, finder in ipairs(finders) do
      if filter.source_id == nil or filter.source_id == source_id then
        results[#results + 1] = finder(opts, ctx) or {}
      else
        results[#results + 1] = {}
      end
      need_async = need_async or type(results[#results]) == "function"
    end

    ---@async
    ---@type snacks.picker.finder.async
    local function collect(cb)
      for source_id, find in ipairs(results) do
        if type(find) == "table" then
          for _, item in ipairs(find) do
            item.source_id = source_id
            cb(item)
          end
        else
          ---@async
          find(function(item)
            item.source_id = source_id
            cb(item)
          end)
        end
      end
    end

    if need_async then
      return collect
    end

    -- not async, so collect all items
    local items = {} ---@type snacks.picker.finder.Item[]
    collect(function(item)
      items[#items + 1] = item
    end)
    return items
  end
end

return M
