---@class snacks.Image
---@field id number
---@field buf number
---@field wins table<number, snacks.image.Dim>
---@field opts snacks.image.Config
---@field file string
---@field _convert uv.uv_process_t?
local M = {}
M.__index = M

M.meta = {
  desc = "Image viewer using Kitty Graphics Protocol, supported by `kitty`, `weztermn` and `ghostty`",
  needs_setup = true,
}

---@class snacks.image.Config
---@field file? string
local defaults = {}
local uv = vim.uv or vim.loop

---@alias snacks.image.Dim {col: number, row: number, width: number, height: number}

local images = {} ---@type table<number, snacks.Image>
local id = 0
local exts = { "png", "jpg", "jpeg", "gif", "bmp", "webp" }

---@param buf number
---@param opts? snacks.image.Config
function M.new(buf, opts)
  if images[buf] then
    return images[buf]
  end
  local file = opts and opts.file or vim.api.nvim_buf_get_name(buf)
  if not M.supports(file) then
    return
  end

  local self = setmetatable({}, M)
  images[buf] = self
  id = id + 1
  self.id = id
  self.file = file
  self.opts = Snacks.config.get("image", defaults, opts or {})

  Snacks.util.bo(buf, {
    filetype = "image",
    buftype = "nofile",
    -- modifiable = false,
    modified = false,
    swapfile = false,
  })
  self.buf = buf
  self.wins = {}

  local group = vim.api.nvim_create_augroup("snacks.image." .. self.id, { clear = true })
  vim.api.nvim_create_autocmd(
    { "VimResized", "BufWinEnter", "WinClosed", "BufWinLeave", "WinNew", "BufEnter", "BufLeave" },
    {
      group = group,
      buffer = self.buf,
      callback = function()
        vim.schedule(function()
          self:update()
        end)
      end,
    }
  )

  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    buffer = self.buf,
    callback = function()
      vim.schedule(function()
        self:hide()
      end)
      pcall(vim.api.nvim_del_augroup_by_id, group)
    end,
  })

  local update = self.update
  self:convert()
  if self:ready() then
    vim.schedule(function()
      self:create()
      self:update()
    end)
  end

  self.update = Snacks.util.debounce(function()
    update(self)
  end, { ms = 50 })
  return self
end

---@param win number
---@return snacks.image.Dim
function M:dim(win)
  local border = setmetatable({ opts = vim.api.nvim_win_get_config(win) }, { __index = Snacks.win }):border_size()
  local pos = vim.api.nvim_win_get_position(win)
  return {
    row = pos[1] + border.top,
    col = pos[2] + border.left,
    width = vim.api.nvim_win_get_width(win),
    height = vim.api.nvim_win_get_height(win),
  }
end

---@param win? number
function M:hide(win)
  self:request({ a = "d", i = self.id, p = win })
end

function M:update()
  if not self:ready() then
    return
  end
  -- hide images that are no longer visible
  for win in pairs(self.wins) do
    local buf = vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win)
    if buf ~= self.buf then
      self:hide(win)
      self.wins[win] = nil
    end
  end

  for _, win in pairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == self.buf then
      self:render(win)
    end
  end
end

---@param win number
function M:render(win)
  if not vim.api.nvim_win_is_valid(win or win) then
    return
  end
  local dim = self:dim(win)
  self.wins[win] = dim
  vim.api.nvim_win_call(win, function()
    io.write("\27[" .. (dim.row + 1) .. ";" .. (dim.col + 1) .. "H")
    self:request({
      a = "p",
      i = self.id,
      p = win,
      c = dim.width,
      r = dim.height,
    })
  end)
end

function M:ready()
  return vim.api.nvim_buf_is_valid(self.buf) and (not self._convert or self._convert:is_closing())
end

function M:create()
  -- create the image
  self:request({
    f = 100,
    s = 2,
    t = "f",
    i = self.id,
    data = self.file,
  })
end

function M:convert()
  local ext = vim.fn.fnamemodify(self.file, ":e")
  if ext == "png" then
    return
  end
  local fin = ext == "gif" and self.file .. "[0]" or self.file
  local root = vim.fn.stdpath("cache") .. "/snacks/image"
  vim.fn.mkdir(root, "p")
  self.file = root .. "/" .. Snacks.util.file_encode(fin) .. ".png"
  if vim.fn.filereadable(self.file) == 1 then
    return
  end
  self._convert = uv.spawn("magick", {
    args = {
      fin,
      self.file,
    },
  }, function()
    self._convert:close()
    vim.schedule(function()
      self:create()
      self:update()
    end)
  end)
end

---@param opts table<string, string|number>|{data?: string}
function M:request(opts)
  opts.q = opts.q or 2 -- silence all
  local msg = {} ---@type string[]
  for k, v in pairs(opts) do
    if k ~= "data" then
      table.insert(msg, string.format("%s=%s", k, v))
    end
  end
  msg = { table.concat(msg, ",") }
  if opts.data then
    msg[#msg + 1] = ";"
    msg[#msg + 1] = vim.base64.encode(opts.data)
  end
  local data = "\27_G" .. table.concat(msg) .. "\27\\"
  io.write(data)
end

---@param file string
function M.supports(file)
  return vim.tbl_contains(exts, vim.fn.fnamemodify(file, ":e"))
end

return M
