---@class snacks.util.spinner.Opts
---@field extmark? fun(spinner:string): vim.api.keyset.set_extmark

---@class snacks.util.Spinner
---@field buf number
---@field opts snacks.util.spinner.Opts
---@field timer? uv.uv_timer_t
---@field extmark_id? number
local M = {}
M.__index = M

local ns = vim.api.nvim_create_namespace("snacks.picker.util.spinner")

---@param opts? snacks.util.spinner.Opts
---@param buf number
function M.new(buf, opts)
  local self = setmetatable({}, M)
  self.buf = buf
  self.opts = opts or {}
  self:start()
  return self
end

function M:start()
  if self:running() then
    return
  end
  self:stop()
  if not self:buf_valid() then
    return
  end
  self.timer = assert(vim.uv.new_timer())
  self.timer:start(0, 60, function()
    vim.schedule(function()
      self:step()
    end)
  end)
end

function M:buf_valid()
  return self.buf and vim.api.nvim_buf_is_valid(self.buf)
end

function M:step()
  if not self:running() then
    return
  end
  if not self:buf_valid() then
    return self:stop()
  end
  local lines = vim.api.nvim_buf_get_lines(self.buf, 0, -1, false)
  local row = math.max(#lines - 1, 0)
  while row > 0 and lines[row + 1]:match("^%s*$") do
    row = row - 1
  end

  local spinner = Snacks.util.spinner()

  ---@type vim.api.keyset.set_extmark
  local extmark = {}
  if type(self.opts.extmark) == "function" then
    extmark = self.opts.extmark(spinner)
  else
    if row > 0 then
      extmark.virt_lines = { { { spinner, "SnacksPickerSpinner" } } }
    else
      extmark.virt_text = { { spinner, "SnacksPickerSpinner" } }
    end
  end
  extmark.id = self.extmark_id
  extmark.priority = 1000
  self.extmark_id = vim.api.nvim_buf_set_extmark(self.buf, ns, row, 0, extmark)
end

function M:running()
  return self.timer and not self.timer:is_closing()
end

function M:stop()
  if self.timer and not self.timer:is_closing() then
    self.timer:stop()
    self.timer:close()
    self.timer = nil
  end
  if self:buf_valid() then
    vim.api.nvim_buf_clear_namespace(self.buf, ns, 0, -1)
  end
end

---@param msg? string
---@param opts? snacks.win.Config
function M.loading(msg, opts)
  opts = opts or {}
  local parent_win = opts.win or vim.api.nvim_get_current_win()
  msg = msg or "Loading..."
  msg = "   " .. msg
  opts = Snacks.win.resolve({
    backdrop = false,
    win = vim.api.nvim_get_current_win(),
    focusable = false,
    enter = false,
    relative = "win",
    zindex = (vim.api.nvim_win_get_config(parent_win).zindex or 50) + 1,
    width = vim.api.nvim_strwidth(msg) + 1,
    height = 1,
    border = "rounded",
    text = msg,
  }, opts)
  local win = Snacks.win(opts)
  local spinner ---@type snacks.util.Spinner
  win:on("WinClosed", function(_, ev)
    if ev.match == tostring(parent_win) then
      win:close()
      spinner:stop()
    end
  end)
  spinner = M.new(win.buf, {
    extmark = function(text)
      return {
        virt_text = { { text, "SnacksPickerSpinner" } },
        virt_text_pos = "overlay",
        virt_text_win_col = 1,
      }
    end,
  })
  local stop = spinner.stop
  spinner.stop = function()
    stop(spinner)
    win:close()
  end
  return spinner
end

return M
