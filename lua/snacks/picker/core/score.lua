--- This is a port of the scoring logic from fzf. See:
--- https://github.com/junegunn/fzf/blob/master/src/algo/algo.go
---@class snacks.picker.Score
---@field score number
---@field consecutive number
---@field prev? number
---@field prev_class number
---@field in_gap boolean
---@field is_file boolean
---@field str string
---@field opts snacks.picker.matcher.Config
local M = {}
M.__index = M

-- Scoring constants. Same as fzf:
local SCORE_MATCH = 16
local SCORE_GAP_START = -3
local SCORE_GAP_EXTENSION = -1

local BONUS_BOUNDARY = SCORE_MATCH / 2 -- 8
local BONUS_NONWORD = SCORE_MATCH / 2 -- 8
local BONUS_CAMEL_123 = BONUS_BOUNDARY - 1 -- 7
local BONUS_CONSECUTIVE = -(SCORE_GAP_START + SCORE_GAP_EXTENSION) -- 4
local BONUS_FIRST_CHAR_MULTIPLIER = 2
local BONUS_NO_PATH_SEP = BONUS_BOUNDARY - 2 -- added when there is no path separator following the from position

local PATH_SEP = package.config:sub(1, 1)

-- ASCII char classes (simplified); adapt as needed:
local CHAR_WHITE = 0
local CHAR_NONWORD = 1
local CHAR_DELIMITER = 2
local CHAR_LOWER = 3
local CHAR_UPPER = 4
local CHAR_LETTER = 5
local CHAR_NUMBER = 6

-- Table to classify ASCII bytes quickly:
local CHAR_CLASS = {} ---@type number[]
for b = 0, 255 do
  local c = CHAR_NONWORD
  local char = string.char(b)
  if char:match("%s") then
    c = CHAR_WHITE
  elseif char:match("[/\\,:;|]") then
    c = CHAR_DELIMITER
  elseif b >= 48 and b <= 57 then -- '0'..'9'
    c = CHAR_NUMBER
  elseif b >= 65 and b <= 90 then -- 'A'..'Z'
    c = CHAR_UPPER
  elseif b >= 97 and b <= 122 then -- 'a'..'z'
    c = CHAR_LOWER
  end
  CHAR_CLASS[b] = c
end

-- A bonus matrix that returns extra points for transitions from prevClass->currClass
local BONUS_MATRIX = {} ---@type number[][]
for i = 0, 6 do
  BONUS_MATRIX[i] = {}
  for j = 0, 6 do
    BONUS_MATRIX[i][j] = 0
  end
end

-- Helper to compute boundary/camelCase bonuses (mimics fzf approach)
local function computeBonus(prevC, currC)
  -- If transitioning from whitespace/delimiter/nonword to letter => boundary bonus
  if currC > CHAR_NONWORD then
    if prevC == CHAR_WHITE then
      return BONUS_BOUNDARY + 2 -- e.g. bonusBoundaryWhite
    elseif prevC == CHAR_DELIMITER then
      return BONUS_BOUNDARY + 1 -- e.g. bonusBoundaryDelimiter
    elseif prevC == CHAR_NONWORD then
      return BONUS_BOUNDARY
    end
  end

  -- camelCase transitions or letter->number transitions
  if (prevC == CHAR_LOWER and currC == CHAR_UPPER) or (prevC ~= CHAR_NUMBER and currC == CHAR_NUMBER) then
    return BONUS_CAMEL_123
  end

  if currC == CHAR_NONWORD or currC == CHAR_DELIMITER then
    return BONUS_NONWORD
  elseif currC == CHAR_WHITE then
    return BONUS_BOUNDARY + 2
  end
  return 0
end

-- Fill in the matrix
for prev = 0, 6 do
  for curr = 0, 6 do
    BONUS_MATRIX[prev][curr] = computeBonus(prev, curr)
  end
end

---@param opts? snacks.picker.matcher.Config
function M.new(opts)
  local self = setmetatable({}, M)
  self.opts = opts or {}
  self.score = 0
  self.is_file = true
  self.consecutive = 0
  self.prev_class = CHAR_WHITE
  self.in_gap = false
  self.str = ""
  return self
end

---@param str string
---@param pos number
function M:is_left_boundary(str, pos)
  return pos == 1 or CHAR_CLASS[str:byte(pos - 1)] < CHAR_LOWER
end

---@param str string
---@param pos number
function M:is_right_boundary(str, pos)
  return pos == #str or CHAR_CLASS[str:byte(pos + 1)] < CHAR_LOWER
end

---@param str string
---@param first number
function M:init(str, first)
  self.str = str
  self.score = 0
  self.consecutive = 0
  self.prev_class = CHAR_WHITE
  self.prev = nil
  if first > 1 then
    self.prev_class = CHAR_CLASS[str:byte(first - 1)] or CHAR_NONWORD
  end
  if
    self.is_file
    and self.opts.filename_bonus
    and not str:find(PATH_SEP, first + 1, true)
    and not (PATH_SEP ~= "/" and str:find("/", first + 1, true))
  then
    self.score = self.score + BONUS_NO_PATH_SEP
  end
  self.in_gap = false
  self:update(first)
end

---@param pos number
function M:update(pos)
  local b = self.str:byte(pos)
  local class = CHAR_CLASS[b] or CHAR_NONWORD

  -- Calculate boundary bonus for transitioning from prevClass->currClass
  local bonus = BONUS_MATRIX[self.prev_class][class] or 0

  -- Handle gap vs consecutive logic
  if self.prev then
    local gap = pos - self.prev - 1
    if gap > 0 then
      -- We have a gap. If we were already in a gap, only extension penalty
      -- otherwise we do a gap start penalty
      self.score = self.score
        + (self.in_gap and (gap * SCORE_GAP_EXTENSION) or (SCORE_GAP_START + (gap - 1) * SCORE_GAP_EXTENSION))

      self.consecutive = 0
      self.in_gap = true
    else
      -- consecutive match => reward
      self.consecutive = self.consecutive + 1
      self.score = self.score + (BONUS_CONSECUTIVE * self.consecutive)
      self.in_gap = false
    end
  else
    bonus = bonus * BONUS_FIRST_CHAR_MULTIPLIER
  end

  -- Add base match + boundary/camel bonus
  self.score = self.score + SCORE_MATCH + bonus

  -- Update for next iteration
  self.prev_class = class
  self.prev = pos
end

---@param str string
---@param from number
---@param to number
function M:get(str, from, to)
  self:init(str, from)
  for i = from + 1, to do
    self:update(i)
  end
  return self.score
end

return M
