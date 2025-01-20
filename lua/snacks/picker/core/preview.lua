---@class snacks.picker.Preview
---@field item? snacks.picker.Item
---@field pos? snacks.picker.Pos
---@field win snacks.win
---@field preview snacks.picker.preview
---@field state table<string, any>
---@field main? number
---@field win_opts {main: snacks.win.Config, layout: snacks.win.Config, win: snacks.win.Config}
---@field winhl string
---@field title? string
local M = {}
M.__index = M

---@class snacks.picker.preview.ctx
---@field picker snacks.Picker
---@field item snacks.picker.Item
---@field prev? snacks.picker.Item
---@field preview snacks.picker.Preview
---@field buf number
---@field win number

local ns = vim.api.nvim_create_namespace("snacks.picker.preview")
local ns_loc = vim.api.nvim_create_namespace("snacks.picker.preview.loc")

---@param opts snacks.picker.Config
---@param main? number
function M.new(opts, main)
  local self = setmetatable({}, M)
  self.winhl = Snacks.picker.highlight.winhl("SnacksPickerPreview", { CursorLine = "Visual" })
  local win_opts = Snacks.win.resolve(
    {
      title_pos = "center",
      minimal = false,
      wo = {
        cursorline = false,
        colorcolumn = "",
        number = true,
        relativenumber = false,
        list = false,
      },
    },
    opts.win.preview,
    {
      show = false,
      enter = false,
      width = 0,
      height = 0,
      fixbuf = false,
      on_win = function()
        self.item = nil
        self:reset()
      end,
      wo = {
        winhighlight = self.winhl,
      },
      scratch_ft = "snacks_picker_preview",
    }
  )
  self.win_opts = {
    main = {
      relative = "win",
      backdrop = false,
    },
    layout = {
      backdrop = win_opts.backdrop == true,
      relative = "win",
    },
  }
  self.win = Snacks.win(win_opts)
  self:update(main)
  self.state = {}

  self.win:on("WinClosed", function()
    self:clear(self.win.buf)
  end, { win = true })

  local preview = opts.preview or Snacks.picker.preview.file
  preview = type(preview) == "string" and Snacks.picker.preview[preview] or preview
  ---@cast preview snacks.picker.preview
  self.preview = preview
  return self
end

function M:close()
  self.win:destroy()
  self.item = nil
  self.win_opts = { main = {}, layout = {}, win = {} }
  self.state = {}
end

---@param main? number
function M:update(main)
  self.main = main
  self.win_opts.main.win = main
  self.win.opts = vim.tbl_deep_extend("force", self.win.opts, main and self.win_opts.main or self.win_opts.layout)
  self.win.opts.wo.winhighlight = main and vim.wo[main].winhighlight or self.winhl
  if main then
    self.win:update()
  end
end

---@param picker snacks.Picker
function M:show(picker)
  local item, prev = picker:current({ resolve = false }), self.item
  if self.item == item and self.pos == (item and item.pos or nil) then
    return
  end
  Snacks.picker.util.resolve(item)
  self.item = item
  self.pos = item and item.pos or nil
  if item then
    local buf = self.win.buf
    local ok, err = pcall(
      self.preview,
      setmetatable({
        preview = self,
        item = item,
        prev = prev,
        picker = picker,
      }, {
        __index = function(_, k)
          if k == "buf" then
            return self.win.buf
          elseif k == "win" then
            return self.win.win
          end
        end,
      })
    )
    if not ok then
      self:notify(err, "error")
    end
    if self.win.buf ~= buf then
      self:clear(buf)
    end
  else
    self:reset()
  end
end

---@param title? string
function M:set_title(title)
  self.title = title
end

---@param wo vim.wo|{}
function M:wo(wo)
  if self.win:win_valid() then
    Snacks.util.wo(self.win.win, wo)
  end
end

---@param buf? number
function M:clear(buf)
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  vim.api.nvim_buf_clear_namespace(buf, ns_loc, 0, -1)
end

function M:reset()
  if vim.api.nvim_buf_is_valid(self.win.scratch_buf) then
    vim.api.nvim_win_set_buf(self.win.win, self.win.scratch_buf)
  else
    self.win:scratch()
  end
  self:set_title()
  vim.treesitter.stop(self.win.buf)
  vim.bo[self.win.buf].modifiable = true
  self:set_lines({})
  self:clear(self.win.buf)
  local ei = vim.o.eventignore
  vim.o.eventignore = "all"
  vim.bo[self.win.buf].filetype = "snacks_picker_preview"
  vim.bo[self.win.buf].syntax = ""
  vim.bo[self.win.buf].buftype = "nofile"
  self:wo({ cursorline = false })
  self:wo(self.win.opts.wo)
  vim.o.eventignore = ei
end

-- create a new scratch buffer
function M:scratch()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  local ei = vim.o.eventignore
  vim.o.eventignore = "all"
  vim.bo[buf].filetype = "snacks_picker_preview"
  vim.o.eventignore = ei
  vim.api.nvim_win_set_buf(self.win.win, buf)
  self.win:map()
  self:wo({ number = false, relativenumber = false, signcolumn = "no" })
  return buf
end

--- highlight the buffer
---@param opts? {file?:string, buf?:number, ft?:string, lang?:string}
function M:highlight(opts)
  opts = opts or {}
  local ft = opts.ft
  if not ft and (opts.file or opts.buf) then
    ft = vim.filetype.match({
      buf = opts.buf or self.win.buf,
      filename = opts.file,
    })
  end
  local lang = opts.lang or ft and vim.treesitter.language.get_lang(ft)
  if not (lang and pcall(vim.treesitter.start, self.win.buf, lang)) then
    if ft then
      vim.bo[self.win.buf].syntax = ft
    end
  end
end

-- show the item location
function M:loc()
  vim.api.nvim_buf_clear_namespace(self.win.buf, ns_loc, 0, -1)
  if not self.item then
    return
  end

  local line_count = vim.api.nvim_buf_line_count(self.win.buf)
  Snacks.picker.util.resolve_loc(self.item, self.win.buf)

  if self.item.pos and self.item.pos[1] > 0 and self.item.pos[1] <= line_count then
    vim.api.nvim_win_set_cursor(self.win.win, { self.item.pos[1], 0 })
    vim.api.nvim_win_call(self.win.win, function()
      vim.cmd("norm! zz")
      self:wo({ cursorline = true })
    end)
    if self.item.end_pos then
      vim.api.nvim_buf_set_extmark(self.win.buf, ns_loc, self.item.pos[1] - 1, self.item.pos[2], {
        end_row = self.item.end_pos[1] - 1,
        end_col = self.item.end_pos[2],
        hl_group = "SnacksPickerSearch",
      })
    end
  elseif self.item.search then
    vim.api.nvim_win_call(self.win.win, function()
      vim.cmd("keepjumps norm! gg")
      if pcall(vim.cmd, self.item.search) then
        vim.cmd("norm! zz")
        self:wo({ cursorline = true })
      end
    end)
  end
end

---@param lines string[]
function M:set_lines(lines)
  vim.bo[self.win.buf].modifiable = true
  vim.api.nvim_buf_set_lines(self.win.buf, 0, -1, false, lines)
  vim.bo[self.win.buf].modifiable = false
end

---@param msg string
---@param level? "info" | "warn" | "error"
---@param opts? {item?:boolean}
function M:notify(msg, level, opts)
  if not self.win:buf_valid() then
    Snacks.notify(msg, { level = level })
    return
  end
  self:reset()
  level = level or "info"
  local lines = vim.split(level .. ": " .. msg, "\n", { plain = true })
  local msg_len = #lines
  if not (opts and opts.item == false) then
    lines[#lines + 1] = ""
    vim.list_extend(lines, vim.split(vim.inspect(self.item), "\n", { plain = true }))
  end
  self:set_lines(lines)
  vim.api.nvim_buf_set_extmark(self.win.buf, ns, 0, 0, {
    hl_group = "Diagnostic" .. level:sub(1, 1):upper() .. level:sub(2),
    end_row = msg_len,
  })
  self:highlight({ lang = "lua" })
end

return M
