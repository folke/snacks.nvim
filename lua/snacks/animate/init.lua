---@class snacks.animate
---@overload fun(from: number, to: number, cb: fun(value: number, prev?: number), opts?: snacks.animate.Opts)
local M = setmetatable({}, {
  __call = function(M, ...)
    return M.animate(...)
  end,
})

-- All easing functions take these parameters:
--
-- t = time     should go from 0 to duration
-- b = begin    value of the property being ease.
-- c = change   ending value of the property - beginning value of the property
-- d = duration
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
---@field int? boolean interpolate the value to an integer
---@field id? number|string unique identifier for the animation

---@class snacks.animate.Animation
---@field from number
---@field to number
---@field duration number
---@field easing snacks.animate.easing.Fn
---@field value number
---@field start number
---@field int boolean
---@field cb fun(value: number, prev?: number)

local uv = vim.uv or vim.loop
local _id = 0
local active = {} ---@type table<number|string, snacks.animate.Animation>
local timer = assert(uv.new_timer())
local todo = {} ---@type table<number|string, {anim:snacks.animate.Animation, values:number[]}>

---@param from number
---@param to number
---@param cb fun(value: number, prev?: number)
---@param opts? snacks.animate.Opts
function M.animate(from, to, cb, opts)
  opts = Snacks.config.get("animate", defaults, opts) --[[@as snacks.animate.Opts]]
  local d = type(opts.duration) == "table" and opts.duration or { step = opts.duration }
  ---@cast d snacks.animate.Duration

  local duration = 0
  if d.step then
    duration = d.step * math.abs(to - from)
    duration = math.min(duration, d.total or duration)
  elseif d.total then
    duration = d.total
  end

  local easing = opts.easing or "linear"
  easing = type(easing) == "string" and require("snacks.animate.easing")[easing] or easing
  ---@cast easing snacks.animate.easing.Fn

  _id = _id + 1
  active[opts.id or _id] = {
    from = from,
    to = to,
    value = from,
    int = opts.int or false,
    duration = duration --[[@as number]],
    easing = easing,
    start = uv.hrtime(),
    cb = cb,
  }
  M.start()
end

function M.step()
  for a, anim in pairs(active) do
    local elapsed = (uv.hrtime() - anim.start) / 1e6 -- ms
    local b, c, d = anim.from, anim.to - anim.from, anim.duration
    local t = math.min(elapsed, d)
    local value = t == d and b + c or anim.easing(t, b, c, d)
    value = anim.int and math.floor(value) or value
    local prev = anim.value
    if prev ~= value then
      todo[a] = { anim = anim, values = { value, prev } }
      anim.value = value
    end
    if t >= d then
      active[a] = nil
    end
  end
  if vim.tbl_isempty(active) then
    timer:stop()
  end
  if not vim.tbl_isempty(todo) then
    vim.schedule(function()
      for _, a in pairs(todo) do
        a.anim.cb(a.values[1], a.values[2])
      end
      todo = {}
    end)
  end
end

function M.start()
  if timer:is_active() then
    return
  end
  local opts = Snacks.config.get("animate", defaults)
  local ms = 1000 / (opts and opts.fps or 30)
  timer:start(0, ms, M.step)
end

return M
