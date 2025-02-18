---@class snacks.Image
---@field src string
---@field file string
---@field id number image id. unique per nvim instance and file
---@field sent? boolean image data is sent
---@field placements table<number, snacks.image.Placement> image placements
---@field augroup number
---@field info? snacks.image.Info
---@field _convert? snacks.image.Convert
local M = {}
M.__index = M

local NVIM_ID_BITS = 10
local CHUNK_SIZE = 4096
local _id = 30
local _pid = 0
local nvim_id = 0
local uv = vim.uv or vim.loop
local images = {} ---@type table<string, snacks.Image>
local terminal = Snacks.image.terminal

---@param src string
function M.new(src)
  local self = setmetatable({}, M)
  self.src = src
  self.file = self:convert()
  if images[self.file] then
    return images[self.file]
  end
  images[self.file] = self
  _id = _id + 1
  local bit = require("bit")
  -- generate a unique id for this nvim instance (10 bits)
  if nvim_id == 0 then
    local pid = vim.fn.getpid()
    nvim_id = bit.band(bit.bxor(pid, bit.rshift(pid, 5), bit.rshift(pid, NVIM_ID_BITS)), 0x3FF)
  end
  -- interleave the nvim id and the image id
  self.id = bit.bor(bit.lshift(nvim_id, 24 - NVIM_ID_BITS), _id)
  self.placements = {}
  self.augroup = vim.api.nvim_create_augroup("snacks.image." .. self.id, { clear = true })

  self:run()
  if self:ready() then
    self:on_ready()
  end

  return self
end

function M:on_ready()
  if not self.sent then
    self.info = self._convert and self._convert.meta.info or nil
    self:send()
  end
end

function M:on_send()
  for _, placement in pairs(self.placements) do
    placement:update()
  end
end

function M:failed()
  if self._convert and not self._convert:done() then
    return false
  end
  if self._convert and self._convert:error() then
    return true
  end
  return self.file and vim.fn.filereadable(self.file) == 0
end

function M:ready()
  if self._convert and not self._convert:done() then
    return false
  end
  return self.file and vim.fn.filereadable(self.file) == 1
end

function M:run()
  if not self._convert then
    return
  end
  self._convert:run(function(convert)
    if convert:error() then
      vim.schedule(function()
        for _, p in pairs(self.placements) do
          p:error()
        end
      end)
    else
      vim.schedule(function()
        self:on_ready()
      end)
    end
  end)
end

function M:convert()
  self._convert = Snacks.image.convert.convert({ src = self.src })
  return self._convert.file
end

-- create the image
function M:send()
  assert(not self.sent, "Image already sent")
  self.sent = true
  -- local image
  if not terminal.env().remote then
    terminal.request({
      t = "f",
      i = self.id,
      f = 100,
      data = Snacks.util.base64(self.file),
    })
  else
    -- remote image
    local fd = assert(io.open(self.file, "rb"), "Failed to open file: " .. self.file)
    local data = fd:read("*a")
    fd:close()
    data = Snacks.util.base64(data) -- encode the data
    local offset = 1
    while offset <= #data do
      local chunk = data:sub(offset, offset + CHUNK_SIZE - 1)
      local first = offset == 1
      offset = offset + CHUNK_SIZE
      local last = offset > #data
      if first then
        terminal.request({
          t = "d",
          i = self.id,
          f = 100,
          m = last and 0 or 1,
          data = chunk,
        })
      else
        terminal.request({
          m = last and 0 or 1,
          data = chunk,
        })
      end
      uv.sleep(1)
    end
  end
  self:on_send()
end

---@param placement snacks.image.Placement
function M:place(placement)
  for pid, p in pairs(self.placements) do
    if p == placement then
      placement.id = pid
      return pid
    end
  end
  _pid = _pid + 1
  placement.id = _pid
  self.placements[_pid] = placement
end

---@param pid? number
function M:del(pid)
  for id, p in ipairs(pid and { pid } or vim.tbl_keys(self.placements)) do
    if self.placements[p] then
      terminal.request({ a = "d", d = "i", i = self.id, p = id })
      self.placements[p] = nil
    end
  end

  if not next(self.placements) then
    terminal.request({ a = "d", d = "i", i = self.id })
    self.sent = false
    pcall(vim.api.nvim_del_autocmd_by_id, self.augroup)
  end
end

return M
