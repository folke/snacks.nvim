---@class snacks.animate
---@overload fun(from: number, to: number, cb: snacks.animate.cb, opts?: snacks.animate.Opts): snacks.animate.Animation
local M = setmetatable({}, {
  __call = function(M, ...)
    return M.add(...)
  end,
})

M.meta = {
  desc = "Efficient animations including over 45 easing functions _(library)_",
}

-- All easing functions take these parameters:
--
-- * `t` _(time)_: should go from 0 to duration
-- * `b` _(begin)_: value of the property being ease.
-- * `c` _(change)_: ending value of the property - beginning value of the property
-- * `d` _(duration)_: total duration of the animation
--
-- Some functions allow additional modifiers, like the elastic functions
-- which also can receive an amplitud and a period parameters (defaults
-- are included)
---@alias snacks.animate.easing.Fn fun(t: number, b: number, c: number, d: number): number

--- Duration can be specified as the total duration or the duration per step.
--- When both are specified, the minimum of both is used.
---@class snacks.animate.Duration
---@field step? number duration per step in ms
---@field total? number total duration in ms

---@class snacks.animate.Config
---@field easing? snacks.animate.easing|snacks.animate.easing.Fn
local defaults = {
  ---@type snacks.animate.Duration|number
  duration = 20, -- ms per step
  easing = "linear",
  fps = 60, -- frames per second. Global setting for all animations
}

---@class snacks.animate.Opts: snacks.animate.Config
---@field buf? number optional buffer to check if animations should be enabled
---@field int? boolean interpolate the value to an integer
---@field id? number|string unique identifier for the animation

---@class snacks.animate.ctx
---@field anim snacks.animate.Animation
---@field prev number
---@field done boolean

---@alias snacks.animate.cb fun(value:number, ctx: snacks.animate.ctx)

local uv = vim.uv or vim.loop
local _id = 0
local active = {} ---@type table<number|string, snacks.animate.Animation>
local timer = assert(uv.new_timer())
local scheduled = false

---@class snacks.animate.Animation
---@field id number|string unique identifier
---@field opts snacks.animate.Opts
---@field from number start value
---@field to number end value
---@field done boolean
---@field duration number total duration in ms
---@field easing snacks.animate.easing.Fn
---@field value number current value
---@field start number start time in ms
---@field cb snacks.animate.cb
---@field stopped? boolean
local Animation = {}
Animation.__index = Animation

---@return number value, boolean done
function Animation:next()
  self.start = self.start == 0 and uv.hrtime() or self.start
  if not self:enabled() then
    return self.to, true
  end
  local elapsed = (uv.hrtime() - self.start) / 1e6 -- ms
  local b, c, d = self.from, self.to - self.from, self.duration
  local t, done = math.min(elapsed, d), elapsed >= d
  local value = done and b + c or self.easing(t, b, c, d)
  value = self.opts.int and (value + (2 ^ 52 + 2 ^ 51) - (2 ^ 52 + 2 ^ 51)) or value
  return value, done
end

function Animation:remaining()
  if not self:enabled() then
    return 0
  end
  local elapsed = (uv.hrtime() - self.start) / 1e6 -- ms
  return math.max(0, self.duration - elapsed)
end

function Animation:enabled()
  return M.enabled({ buf = self.opts.buf, name = tostring(self.id) })
end

---@return boolean done
function Animation:update()
  if self.stopped then
    return true
  end
  local value, done = self:next()
  local prev = self.value
  if prev ~= value or done then
    self.cb(value, { anim = self, prev = prev, done = done })
    self.value = value
    self.done = done
  end
  return done
end

function Animation:dirty()
  local value, done = self:next()
  return self.value ~= value or done
end

function Animation:stop()
  self.stopped = true
  active[self.id] = nil
end

--- Check if animations are enabled.
--- Will return false if `snacks_animate` is set to false or if the buffer
--- local variable `snacks_animate` is set to false.
---@param opts? {buf?: number, name?: string}
function M.enabled(opts)
  opts = opts or {}
  if opts.name and not M.enabled({ buf = opts.buf }) then
    return false
  end
  local key = "snacks_animate" .. (opts.name and ("_" .. opts.name) or "")
  return Snacks.util.var(opts.buf, key, true)
end

--- Add an animation
---@param from number
---@param to number
---@param cb snacks.animate.cb
---@param opts? snacks.animate.Opts
function M.add(from, to, cb, opts)
  opts = Snacks.config.get("animate", defaults, opts) --[[@as snacks.animate.Opts]]

  -- calculate duration
  local d = type(opts.duration) == "table" and opts.duration or { step = opts.duration }
  ---@cast d snacks.animate.Duration
  local duration = 0
  if d.step then
    duration = d.step * math.abs(to - from)
    duration = math.min(duration, d.total or duration)
  elseif d.total then
    duration = d.total
  end

  -- resolve easing function
  local easing = opts.easing or "linear"
  easing = type(easing) == "string" and require("snacks.animate.easing")[easing] or easing
  ---@cast easing snacks.animate.easing.Fn

  _id = _id + 1
  ---@type snacks.animate.Animation
  local ret = setmetatable({
    id = opts.id or _id,
    opts = opts,
    from = from,
    to = to,
    value = from,
    duration = duration --[[@as number]],
    easing = easing,
    start = 0,
    cb = cb,
  }, Animation)
  M.del(ret.id)
  active[ret.id] = ret
  M.start()
  return ret
end

--- Delete an animation
---@param id number|string
function M.del(id)
  if active[id] then
    active[id]:stop()
    active[id] = nil
  end
end

--- Step the animations and stop loop if no animations are active
---@private
function M.step()
  if scheduled then -- no need to check this step
    return
  elseif vim.tbl_isempty(active) then
    return timer:stop()
  end

  -- check if any animation needs to be updated
  local update = false
  for _, anim in pairs(active) do
    if anim:dirty() then
      update = true
      break
    end
  end

  if update then
    -- schedule an update
    scheduled = true
    vim.schedule(function()
      scheduled = false
      for a, anim in pairs(active) do
        if anim:update() then
          active[a] = nil
        end
      end
    end)
  end
end

--- Start the animation loop
---@private
function M.start()
  if timer:is_active() then
    return
  end
  local opts = Snacks.config.get("animate", defaults)
  local ms = 1000 / (opts and opts.fps or 30)
  timer:start(0, ms, M.step)
end

return M
