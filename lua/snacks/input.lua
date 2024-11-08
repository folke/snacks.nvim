---@class snacks.input
local M = {}

---@class snacks.input.Config
---@field win? snacks.win.Config
---@field icon? string
local defaults = {
  icon = " ",
  icon_hl = "DiagnosticInfo",
  win = { style = "input" },
  expand = true,
}

Snacks.config.style("input", {
  backdrop = false,
  position = "float",
  relative = "cursor",
  border = "rounded",
  height = 1,
  width = 20,
  row = -3,
  col = 0,
})

---@class snacks.input.Opts: snacks.input.Config
---@field prompt? string
---@field default? string
---@field completion? string
---@field highlight? fun()

---@class snacks.input.ctx
---@field opts? snacks.input.Opts
---@field win? snacks.win
local ctx = {}

---@param opts? snacks.input.Opts
---@param on_confirm fun(value?: string)
function M.input(opts, on_confirm)
  local current_win = vim.api.nvim_get_current_win()

  local function confirm(value)
    ctx.win = nil
    ctx.opts = nil
    vim.cmd.stopinsert()
    vim.schedule_wrap(on_confirm)(value)
  end

  opts = Snacks.config.get("input", defaults, opts) --[[@as snacks.input.Opts]]

  opts.win = Snacks.win.resolve("input", opts.win, {
    enter = true,
    title = (" %s "):format(opts.prompt or "Input"),
    title_pos = "center",
    bo = {
      modifiable = true,
      completefunc = "v:lua.Snacks.input.complete",
      omnifunc = "v:lua.Snacks.input.complete",
    },
    wo = { statuscolumn = " %#" .. opts.icon_hl .. "#" .. opts.icon .. " " },
    keys = {
      i_esc = {
        "<esc>",
        function(self)
          confirm()
          self:close()
        end,
        mode = "i",
      },
      i_cr = {
        "<cr>",
        ---@param self snacks.win
        function(self)
          if vim.fn.pumvisible() == 1 then
            return "<C-y>"
          end
          confirm(self:text())
          self:close()
        end,
        expr = true,
        mode = "i",
      },
      i_tab = {
        "<tab>",
        function(self)
          if vim.fn.pumvisible() == 1 then
            return "<C-n>"
          else
            return "<C-x><C-u>"
          end
        end,
        expr = true,
        mode = "i",
      },
    },
  })

  local win = Snacks.win(opts.win)
  ctx = { opts = opts, win = win }
  vim.cmd.startinsert()
  if opts.default then
    vim.api.nvim_buf_set_lines(win.buf, 0, -1, false, { opts.default })
    vim.api.nvim_win_set_cursor(win.win, { 1, #opts.default + 1 })
  end

  if opts.expand then
    vim.api.nvim_create_autocmd("TextChangedI", {
      buffer = win.buf,
      callback = function()
        win.opts.width = math.max(opts.win.width, vim.fn.strdisplaywidth(win:text()) + 5)
        vim.api.nvim_win_call(current_win, function()
          win:update()
        end)
        vim.api.nvim_win_call(win.win, function()
          vim.fn.winrestview({ leftcol = 0 })
        end)
      end,
    })
  end

  return win
end

---@param findstart number
---@param base string
function M.complete(findstart, base)
  local completion = ctx.opts.completion
  if findstart == 1 then
    return 0
  end
  if not completion then
    return {}
  end
  local ok, results = pcall(vim.fn.getcompletion, base, completion)
  return ok and results or {}
end

function M.test()
  M.input({ prompt = "Yes?", default = "/", completion = "file" }, function(value)
    dd(value)
  end)
end

return M
