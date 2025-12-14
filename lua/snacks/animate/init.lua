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
-- * `b` _(begin)_: starting value of the property
-- * `c` _(change)_: ending value of the property - starting value
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
  fps = 120, -- frames per second. Global setting for all animations
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

local function next_id()
  _id = _id + 1
  return _id
end

---@type table<number|string, snacks.animate.Animation>
local active = setmetatable({}, { __mode = "v" })

---@class snacks.animate.Animation
---@field id number|string unique identifier
---@field opts snacks.animate.Opts
---@field easing snacks.animate.easing.Fn
---@field timer? uv.uv_timer_t
---@field steps? number[]
---@field _step? number
local Animation = {}
Animation.__index = Animation

---@param opts? snacks.animate.Opts
function Animation.new(opts)
  local id = opts and opts.id or next_id()

  if active[id] then
    active[id]:stop()
    active[id] = nil
  end

  local self = setmetatable({}, Animation)
  self.id = id
  self.opts = Snacks.config.get("animate", defaults, opts) --[[@as snacks.animate.Opts]]

  -- resolve easing function
  local easing = self.opts.easing or "linear"
  -- easing = easing == "linear" and self.opts.int and "linear_int" or easing
  easing = type(easing) == "string" and require("snacks.animate.easing")[easing] or easing
  ---@cast easing snacks.animate.easing.Fn
  self.easing = easing
  active[self.id] = self

  return self
end

---@param from number
---@param to number
---@param cb snacks.animate.cb
function Animation:start(from, to, cb)
  self:stop()
  if from == to then
    cb(from, { anim = self, prev = from, done = true })
    return self
  end

  -- calculate duration
  local d = type(self.opts.duration) == "table" and self.opts.duration or { step = self.opts.duration }
  ---@cast d snacks.animate.Duration
  local duration = 0
  if d.step then
    duration = d.step * math.abs(to - from)
    duration = math.min(duration, d.total or duration)
  elseif d.total then
    duration = d.total
  end
  duration = duration or 250
  local step_duration = math.max(duration / (to - from), 1000 / self.opts.fps)
  -- local step_duration = math.max(duration / (to - from), 1)
  local step_count = math.max(math.floor(duration / step_duration + 0.5), 10)

  local delta = 0
  if (self.opts.easing or "linear") == "linear" and self.opts.int then
    local one_step = math.max(1, math.floor(math.abs(to - from) / step_count + 0.5))
    step_count = math.floor(math.abs(to - from) / one_step + 0.5)
    delta = math.abs(to - from) - one_step * step_count
    step_duration = duration / step_count
  end

  self.steps = {}
  for i = 1, step_count do
    local value = 0
    if i == step_count then
      value = to
    else
      value = self.easing(i, from, to - from - delta, step_count)
    end
    if self.opts.int then
      value = math.floor(value + 0.5)
    end
    table.insert(self.steps, value)
  end
  self._step = 0
  active[self.id] = self
  self.timer = assert(uv.new_timer())
  self.timer:start(0, step_duration, function()
    vim.schedule(function()
      self:step(cb)
    end)
  end)
  return self
end

---@param cb snacks.animate.cb
function Animation:step(cb)
  if not self.steps or not self._step or self._step >= #self.steps then
    return self:stop()
  end
  self._step = self._step + 1
  local value = self.steps[self._step]
  local done = self._step >= #self.steps
  local prev = self.steps[self._step - 1] or value
  cb(value, { anim = self, prev = prev, done = done })
end

function Animation:stop()
  if self.timer then
    if self.timer:is_active() then
      self.timer:stop()
      self.timer:close()
      self.timer = nil
    end
  end
  self.steps, self._step = nil, nil
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
  return Animation.new(opts):start(from, to, cb)
end

--- Delete an animation
---@param id number|string
function M.del(id)
  if active[id] then
    active[id]:stop()
    active[id] = nil
  end
end

return M
