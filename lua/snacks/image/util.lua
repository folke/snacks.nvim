---@class snacks.image.util
local M = {}

local dims = {} ---@type table<string, snacks.image.Size>

--- Get the dimensions of a PNG file
---@param file string
---@return snacks.image.Size
function M.dim(file)
  file = vim.fs.normalize(file)
  if dims[file] then
    return dims[file]
  end
  -- extract header with IHDR chunk
  local fd = assert(io.open(file, "rb"), "Failed to open file: " .. file)
  local header = fd:read(24) ---@type string
  fd:close()

  -- Check PNG signature
  assert(header:sub(1, 8) == "\137PNG\r\n\26\n", "Not a valid PNG file: " .. file)

  -- Extract width and height from the IHDR chunk
  local width = header:byte(17) * 16777216 + header:byte(18) * 65536 + header:byte(19) * 256 + header:byte(20)
  local height = header:byte(21) * 16777216 + header:byte(22) * 65536 + header:byte(23) * 256 + header:byte(24)
  dims[file] = { width = width, height = height }
  return dims[file]
end

---@param size snacks.image.Size
function M.pixels_to_cells(size)
  local terminal = Snacks.image.terminal.size()
  return M.norm({
    width = size.width / terminal.cell_width * terminal.scale,
    height = size.height / terminal.cell_height * terminal.scale,
  })
end

---@param size snacks.image.Size
---@return snacks.image.Size
function M.norm(size)
  return {
    width = math.max(1, math.floor(size.width + 0.5)),
    height = math.max(1, math.floor(size.height + 0.5)),
  }
end

---@param file string
---@param cells snacks.image.Size size in rows x columns
function M.fit(file, cells)
  local img_pixels = M.dim(file)
  local img_cells = M.pixels_to_cells(img_pixels)

  if img_cells.width <= cells.width and img_cells.height <= cells.height then
    return img_cells
  end

  local ret = vim.deepcopy(cells)
  ret.width = math.min(cells.width, img_cells.width)
  ret.height = math.min(cells.height, img_cells.height)

  local scale = ret.width / ret.height
  local img_scale = img_cells.width / img_cells.height
  local fit_height = math.floor(ret.width / img_scale + 0.5)
  local fit_width = math.floor(ret.height * img_scale + 0.5)

  if ret.height == fit_height or ret.width == fit_width then
    -- Image fits exactly
  elseif img_scale > scale then
    -- Image is wider relative to height - fit to width
    ret.height = fit_height
  else
    -- Image is taller relative to width - fit to height
    ret.width = fit_width
  end
  return M.norm(ret)
end

return M
