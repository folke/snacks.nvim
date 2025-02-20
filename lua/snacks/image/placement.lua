---@class snacks.image.Placement
---@field img snacks.Image
---@field id number image placement id
---@field ns number
---@field buf number
---@field opts snacks.image.Opts
---@field augroup number
---@field closed? boolean
---@field extmark_id? number
---@field _loc? snacks.image.Loc
---@field _state? snacks.image.State
local M = {}
M.__index = M

local terminal = Snacks.image.terminal
local uv = vim.uv or vim.loop
local PLACEHOLDER = vim.fn.nr2char(0x10EEEE)
-- stylua: ignore
local diacritics = vim.split( "0305,030D,030E,0310,0312,033D,033E,033F,0346,034A,034B,034C,0350,0351,0352,0357,035B,0363,0364,0365,0366,0367,0368,0369,036A,036B,036C,036D,036E,036F,0483,0484,0485,0486,0487,0592,0593,0594,0595,0597,0598,0599,059C,059D,059E,059F,05A0,05A1,05A8,05A9,05AB,05AC,05AF,05C4,0610,0611,0612,0613,0614,0615,0616,0617,0657,0658,0659,065A,065B,065D,065E,06D6,06D7,06D8,06D9,06DA,06DB,06DC,06DF,06E0,06E1,06E2,06E4,06E7,06E8,06EB,06EC,0730,0732,0733,0735,0736,073A,073D,073F,0740,0741,0743,0745,0747,0749,074A,07EB,07EC,07ED,07EE,07EF,07F0,07F1,07F3,0816,0817,0818,0819,081B,081C,081D,081E,081F,0820,0821,0822,0823,0825,0826,0827,0829,082A,082B,082C,082D,0951,0953,0954,0F82,0F83,0F86,0F87,135D,135E,135F,17DD,193A,1A17,1A75,1A76,1A77,1A78,1A79,1A7A,1A7B,1A7C,1B6B,1B6D,1B6E,1B6F,1B70,1B71,1B72,1B73,1CD0,1CD1,1CD2,1CDA,1CDB,1CE0,1DC0,1DC1,1DC3,1DC4,1DC5,1DC6,1DC7,1DC8,1DC9,1DCB,1DCC,1DD1,1DD2,1DD3,1DD4,1DD5,1DD6,1DD7,1DD8,1DD9,1DDA,1DDB,1DDC,1DDD,1DDE,1DDF,1DE0,1DE1,1DE2,1DE3,1DE4,1DE5,1DE6,1DFE,20D0,20D1,20D4,20D5,20D6,20D7,20DB,20DC,20E1,20E7,20E9,20F0,2CEF,2CF0,2CF1,2DE0,2DE1,2DE2,2DE3,2DE4,2DE5,2DE6,2DE7,2DE8,2DE9,2DEA,2DEB,2DEC,2DED,2DEE,2DEF,2DF0,2DF1,2DF2,2DF3,2DF4,2DF5,2DF6,2DF7,2DF8,2DF9,2DFA,2DFB,2DFC,2DFD,2DFE,2DFF,A66F,A67C,A67D,A6F0,A6F1,A8E0,A8E1,A8E2,A8E3,A8E4,A8E5,A8E6,A8E7,A8E8,A8E9,A8EA,A8EB,A8EC,A8ED,A8EE,A8EF,A8F0,A8F1,AAB0,AAB2,AAB3,AAB7,AAB8,AABE,AABF,AAC1,FE20,FE21,FE22,FE23,FE24,FE25,FE26,10A0F,10A38,1D185,1D186,1D187,1D188,1D189,1D1AA,1D1AB,1D1AC,1D1AD,1D242,1D243,1D244", ",")
---@type table<number, string>
local positions = {}
setmetatable(positions, {
  __index = function(_, k)
    positions[k] = vim.fn.nr2char(tonumber(diacritics[k], 16))
    return positions[k]
  end,
})

---@param buf number
---@param opts? snacks.image.Opts
function M.new(buf, src, opts)
  assert(type(buf) == "number", "`Image.new`: buf should be a number")
  assert(type(src) == "string", "`Image.new`: src should be a string")
  Snacks.image.setup() -- always setup so that images/videos can be opened
  local self = setmetatable({}, M)

  self.img = Snacks.image.image.new(src)
  self.img:place(self)
  self.opts = opts or {}
  self.buf = buf
  self.ns = vim.api.nvim_create_namespace("snacks.image." .. self.id)
  self.augroup = vim.api.nvim_create_augroup("snacks.image." .. self.id, { clear = true })

  vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter", "BufWinLeave", "BufEnter" }, {
    group = self.augroup,
    buffer = self.buf,
    callback = function()
      vim.schedule(function()
        self:update()
      end)
    end,
  })
  vim.api.nvim_create_autocmd({ "WinClosed", "WinNew", "WinEnter", "WinResized" }, {
    group = self.augroup,
    callback = function()
      vim.schedule(function()
        self:update()
      end)
    end,
  })

  vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, {
    group = self.augroup,
    buffer = self.buf,
    once = true,
    callback = function()
      vim.schedule(function()
        self:close()
      end)
    end,
  })
  vim.api.nvim_create_autocmd({ "ExitPre" }, {
    group = self.augroup,
    once = true,
    callback = function()
      self:close()
    end,
  })

  if self:ready() then
    vim.schedule(function()
      self:update()
    end)
  elseif self.img:failed() then
    self:error()
  else
    self:progress()
  end

  local update = self.update
  self.update = Snacks.util.debounce(function()
    update(self)
  end, { ms = 10 })
  return self
end

function M:error()
  if self.opts.inline then
    return
  end
  local msg = "# Image Conversion Failed:\n\n"
  local convert = self.img._convert
  if convert then
    for _, step in ipairs(convert.steps) do
      if step.err then
        msg = msg .. "## " .. step.name .. "\n\n" .. step.err .. "\n\n"
        if step.proc then
          msg = msg
            .. Snacks.debug.cmd({
              cmd = step.proc.opts.cmd,
              args = step.proc.opts.args,
              cwd = step.proc.opts.cwd,
              notify = false,
            })
          msg = msg .. "\n\n# Output\n" .. vim.trim(step.proc:out() .. "\n" .. step.proc:err()) .. "\n"
        end
      end
    end
  end
  local lines = vim.split(msg, "\n")
  vim.bo[self.buf].modifiable = true
  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, lines)
  vim.bo[self.buf].modifiable = false
  if not vim.treesitter.start(self.buf, "markdown") then
    vim.bo[self.buf].syntax = "markdown"
  end
end

function M:progress()
  if self.opts.inline or self:ready() then
    return
  end
  vim.bo[self.buf].modifiable = true
  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, {})
  vim.bo[self.buf].modifiable = false
  local timer = assert(uv.new_timer())
  timer:start(
    0,
    80,
    vim.schedule_wrap(function()
      if self:ready() or self.img:failed() or not vim.api.nvim_buf_is_valid(self.buf) then
        timer:stop()
        if not timer:is_closing() then
          timer:close()
        end
        return
      end
      vim.api.nvim_buf_clear_namespace(self.buf, self.ns, 0, -1)
      vim.api.nvim_buf_set_extmark(self.buf, self.ns, 0, 0, {
        virt_text = {
          { Snacks.util.spinner(), "SnacksImageSpinner" },
          { " " },
          { self.img._convert:current().name .. " loading …", "SnacksImageLoading" },
        },
      })
    end)
  )
end

---@return number[]
function M:wins()
  ---@param win number
  return vim.tbl_filter(function(win)
    return vim.api.nvim_win_get_buf(win) == self.buf
  end, vim.api.nvim_tabpage_list_wins(0))
end

function M:close()
  if self.closed then
    return
  end
  self.closed = true
  self:debug("close")
  self:hide()
  pcall(vim.api.nvim_del_augroup_by_id, self.augroup)
end

--- Renders the unicode placeholder grid in the buffer
---@param loc snacks.image.Loc
function M:render_grid(loc)
  local hl = "SnacksImage" .. self.id -- image id is encoded in the foreground color
  Snacks.util.set_hl({
    [hl] = {
      fg = self.img.id,
      sp = self.id,
      bg = Snacks.image.config.debug.placement and "#FF007C" or nil,
    },
  })
  local lines = {} ---@type string[]
  for r = 1, loc.height do
    local line = {} ---@type string[]
    for c = 1, loc.width do
      -- cell positions are encoded as diacritics for the placeholder unicode character
      line[#line + 1] = PLACEHOLDER
      line[#line + 1] = positions[r]
      line[#line + 1] = positions[c]
    end
    lines[#lines + 1] = table.concat(line)
  end

  if self.opts.inline then
    local padding = string.rep(" ", loc[2])
    vim.api.nvim_buf_clear_namespace(self.buf, self.ns, 0, -1)
    local start_row, start_col = loc[1] - 1, loc[2]
    local end_row, end_col ---@type number?, number?
    local conceal = Snacks.image.config.doc.conceal and " " or nil
    if self.opts.range and conceal then
      start_row, start_col = self.opts.range[1] - 1, self.opts.range[2]
      end_row, end_col = self.opts.range[3] - 1, self.opts.range[4]
    end
    self.extmark_id = vim.api.nvim_buf_set_extmark(self.buf, self.ns, start_row, start_col, {
      end_row = end_row,
      end_col = end_col,
      conceal = conceal,
      id = self.extmark_id,
      ---@param l string
      virt_lines = vim.tbl_map(function(l)
        return { { padding }, { l, hl } }
      end, lines),
      strict = false,
      invalidate = vim.fn.has("nvim-0.10") == 1 and true or nil,
    })
  else
    vim.bo[self.buf].modifiable = true
    vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, lines)
    vim.bo[self.buf].modifiable = false
    vim.bo[self.buf].modified = false
    for r = 1, loc.height do
      vim.api.nvim_buf_set_extmark(self.buf, self.ns, r - 1, 0, {
        end_col = #lines[r],
        hl_group = hl,
      })
    end
  end
end

function M:hide()
  if vim.api.nvim_buf_is_valid(self.buf) then
    vim.api.nvim_buf_clear_namespace(self.buf, self.ns, 0, -1)
  end
  self.img:del(self.id)
end

---@param state snacks.image.State
function M:render_fallback(state)
  if not self.opts.inline then
    vim.api.nvim_buf_clear_namespace(self.buf, self.ns, 0, -1)
  end
  for _, win in ipairs(state.wins) do
    self:debug("render_fallback", win)
    local border = setmetatable({ opts = vim.api.nvim_win_get_config(win) }, { __index = Snacks.win }):border_size()
    local pos = vim.api.nvim_win_get_position(win)
    terminal.set_cursor({ pos[1] + 1 + border.top, pos[2] + border.left })
    terminal.request({
      a = "p",
      i = self.img.id,
      p = self.id,
      C = 1,
      c = state.loc.width,
      r = state.loc.height,
    })
  end
end

function M:debug(...)
  if true or not Snacks.image.config.debug then
    return
  end
  Snacks.debug.inspect({ ... }, self.img.src, self.img.id, self.id)
end

function M:state()
  local width, height = vim.o.columns, vim.o.lines
  local wins = {} ---@type number[]
  local is_fallback = not terminal.env().placeholders
  local zindex = vim.api.nvim_win_get_config(0).zindex or 0

  for _, win in ipairs(self:wins()) do
    width = math.min(width, vim.api.nvim_win_get_width(win))
    height = math.min(height, vim.api.nvim_win_get_height(win))
    if is_fallback then
      local z = vim.api.nvim_win_get_config(win).zindex or 0
      if z >= zindex or (zindex > 0 and z > 0) then
        wins[#wins + 1] = win -- use if higher z-index or both are floating
      end
    else
      wins[#wins + 1] = win
    end
  end

  local function minmax(value, min, max)
    return math.max(min or 1, math.min(value, max or value))
  end

  width = minmax(self.opts.width or width, self.opts.min_width, self.opts.max_width)
  height = minmax(self.opts.height or height, self.opts.min_height, self.opts.max_height)
  local size = Snacks.image.util.fit(self.img.file, { width = width, height = height }, { info = self.img.info })

  local pos = self.opts.pos or { 1, 0 }
  ---@class snacks.image.State
  ---@field loc snacks.image.Loc
  ---@field wins number[]
  return {
    loc = {
      pos[1],
      pos[2],
      width = size.width,
      height = size.height,
    },
    wins = wins,
  }
end

function M:update()
  if not self:ready() then
    return
  end

  if self.opts.on_update_pre then
    self.opts.on_update_pre(self)
  end

  local state = self:state()
  if vim.deep_equal(state, self._state) then
    return
  end
  self._state = state

  if #state.wins == 0 then
    self:hide()
    return
  end
  self.img:place(self)

  self:debug("update")

  if not self.opts.inline then
    for _, win in ipairs(state.wins) do
      Snacks.util.wo(win, Snacks.image.config.wo or {})
    end
  end

  if terminal.env().placeholders then
    terminal.request({
      a = "p",
      U = 1,
      i = self.img.id,
      p = self.id,
      C = 1,
      c = state.loc.width,
      r = state.loc.height,
    })
    self:render_grid(state.loc)
  else
    self:render_fallback(state)
  end

  if not self.opts.inline then
    for _, win in ipairs(state.wins) do
      vim.api.nvim_win_call(win, function()
        vim.fn.winrestview({ topline = 1, lnum = 1, col = 0, leftcol = 0 })
      end)
    end
  end
  if self.opts.on_update then
    self.opts.on_update(self)
  end
end

function M:ready()
  return not self.closed and self.buf and vim.api.nvim_buf_is_valid(self.buf) and self.img:ready()
end

return M
