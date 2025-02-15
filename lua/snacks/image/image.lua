---@class snacks.Image
---@field src string
---@field file string
---@field id number image id. unique per nvim instance and file
---@field sent? boolean image data is sent
---@field placements table<number, snacks.image.Placement> image placements
---@field augroup number
---@field _convert uv.uv_process_t?
local M = {}
M.__index = M

local NVIM_ID_BITS = 10
local CHUNK_SIZE = 4096
local _id = 30
local _pid = 0
local nvim_id = 0
local uv = vim.uv or vim.loop
local images = {} ---@type table<string, snacks.Image>
local have_magick ---@type boolean?
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
  if self:ready() then
    vim.schedule(function()
      self:on_ready()
    end)
  end
  self.augroup = vim.api.nvim_create_augroup("snacks.image." .. self.id, { clear = true })

  return self
end

function M:on_ready()
  self:send()
end

function M:on_send()
  for _, placement in pairs(self.placements) do
    placement:update()
  end
end

function M:ready()
  return (not self._convert or self._convert:is_closing()) and (self.file and vim.fn.filereadable(self.file) == 1)
end

function M:convert()
  local src = self.src
  if src:find("^file://") then
    src = vim.uri_to_fname(src)
  end
  -- convert urls and non-png files to png
  if not src:find("^https?://") and src:lower():find("%.png$") then
    return src
  end
  if not src:find("^%w%w+://") then
    src = vim.fs.normalize(src)
  end
  local fin = src .. "[0]"
  local root = vim.fn.stdpath("cache") .. "/snacks/image"
  vim.fn.mkdir(root, "p")
  src = root .. "/" .. Snacks.util.file_encode(fin) .. ".png"
  if vim.fn.filereadable(src) == 1 then
    return src
  end
  local opts = { args = { fin, src } }
  have_magick = have_magick == nil and vim.fn.executable("magick") == 1 or have_magick
  self._convert = uv.spawn(have_magick and "magick" or "convert", opts, function(code)
    self._convert:close()
    if code == 0 then
      vim.schedule(function()
        self:on_ready()
      end)
    end
  end)
  return self.src
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
