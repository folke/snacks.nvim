---@class snacks.input
---@overload fun(opts: snacks.input.Opts, on_confirm: fun(value?: string)): snacks.win
local M = setmetatable({}, {
  __call = function(M, ...)
    return M.input(...)
  end,
})

M.meta = {
  desc = "Better `vim.ui.input`",
  needs_setup = true,
}

---@alias snacks.input.Pos "left"|"title"|false

---@class snacks.input.Config
---@field enabled? boolean
---@field win? snacks.win.Config|{}
---@field icon? string
---@field icon_pos? snacks.input.Pos
---@field prompt_pos? snacks.input.Pos
local defaults = {
  icon = " ",
  icon_hl = "SnacksInputIcon",
  icon_pos = "left",
  prompt_pos = "title",
  win = { style = "input" },
  expand = true,
}

Snacks.util.set_hl({
  Icon = "DiagnosticHint",
  Normal = "Normal",
  Border = "DiagnosticInfo",
  Title = "DiagnosticInfo",
  Prompt = "SnacksInputTitle",
}, { prefix = "SnacksInput", default = true })

Snacks.config.style("input", {
  backdrop = false,
  position = "float",
  border = true,
  title_pos = "center",
  height = 1,
  width = 60,
  relative = "editor",
  noautocmd = true,
  row = 2,
  -- relative = "cursor",
  -- row = -3,
  -- col = 0,
  wo = {
    winhighlight = "NormalFloat:SnacksInputNormal,FloatBorder:SnacksInputBorder,FloatTitle:SnacksInputTitle",
    cursorline = false,
  },
  bo = {
    filetype = "snacks_input",
    buftype = "prompt",
  },
  --- buffer local variables
  b = {
    completion = false, -- disable blink completions in input
  },
  keys = {
    n_esc = { "<esc>", { "cmp_close", "cancel" }, mode = "n", expr = true },
    i_esc = { "<esc>", { "cmp_close", "stopinsert" }, mode = "i", expr = true },
    i_cr = { "<cr>", { "cmp_accept", "confirm" }, mode = { "i", "n" }, expr = true },
    i_tab = { "<tab>", { "cmp_select_next", "cmp" }, mode = "i", expr = true },
    i_ctrl_w = { "<c-w>", "<c-s-w>", mode = "i", expr = true },
    i_up = { "<up>", { "hist_up" }, mode = { "i", "n" } },
    i_down = { "<down>", { "hist_down" }, mode = { "i", "n" } },
    q = "cancel",
  },
})

local ui_input = vim.ui.input

---@alias snacks.input.Highlight {[1]:number, [2]:number, [3]:string}

---@class snacks.input.Opts: snacks.input.Config,{}
---@field prompt? string
---@field default? string
---@field completion? string
---@field highlight? fun(text: string): snacks.input.Highlight[]

---@class snacks.input.ctx
---@field opts? snacks.input.Opts
---@field win? snacks.win
local ctx = {}

local ns = vim.api.nvim_create_namespace("snacks.input")

---@param opts? snacks.input.Opts
---@param on_confirm fun(value?: string)
function M.input(opts, on_confirm)
  assert(type(on_confirm) == "function", "`on_confirm` must be a function")

  local history = require("snacks.picker.util.history").new("input", {
    filter = function(value)
      return value ~= ""
    end,
  })

  local parent_win = vim.api.nvim_get_current_win()
  local mode = vim.fn.mode()

  ---@param force? boolean
  local function record(force)
    if not ctx.win then
      return
    end
    if not force and not history:is_current() then
      return
    end
    local text = vim.trim(ctx.win:text())
    if text == "" then
      return
    end
    history:record(text)
  end

  local function confirm(value)
    record()
    ctx.win = nil
    ctx.opts = nil
    vim.cmd.stopinsert()
    vim.schedule(function()
      if vim.api.nvim_win_is_valid(parent_win) then
        vim.api.nvim_set_current_win(parent_win)
        if mode == "i" then
          vim.cmd("startinsert")
        end
      end
      on_confirm(value)
    end)
  end

  opts = Snacks.config.get("input", defaults, opts) --[[@as snacks.input.Opts]]
  opts.prompt = opts.prompt or "Input"
  opts.prompt = vim.trim(opts.prompt)
  opts.prompt = opts.prompt_pos == "title" and opts.prompt:gsub(":$", "") or opts.prompt

  local title, statuscolumn = {}, {} ---@type string[], string[]
  local function add(text, hl, pos)
    if pos == "title" then
      table.insert(title, { " " .. text, hl })
    else
      table.insert(statuscolumn, "%#" .. hl .. "#" .. text)
    end
  end

  if opts.icon_pos and (opts.icon or "") ~= "" then
    add(opts.icon, "SnacksInputIcon", opts.icon_pos)
  end
  add(opts.prompt, "SnacksInputTitle", opts.prompt_pos)

  if next(title) then
    table.insert(title, { " ", "SnacksInputTitle" })
  end

  ---@param text? string
  local function set(text)
    text = text or ""
    vim.api.nvim_buf_set_lines(ctx.win.buf, 0, -1, false, { text })
    vim.api.nvim_win_set_cursor(ctx.win.win, { 1, #text })
  end

  opts.win = Snacks.win.resolve("input", opts.win, {
    enter = true,
    title = next(title) and title or nil,
    bo = {
      modifiable = true,
      completefunc = "v:lua.Snacks.input.complete",
      omnifunc = "v:lua.Snacks.input.complete",
    },
    wo = {
      statuscolumn = next(statuscolumn) and " " .. table.concat(statuscolumn, " ") .. " " or " ",
    },
    actions = {
      cancel = function(self)
        confirm()
        self:close()
      end,
      stopinsert = function()
        vim.schedule(function()
          vim.cmd("stopinsert")
        end)
      end,
      confirm = function(self)
        confirm(self:text())
        self:close()
      end,
      hist_up = function(self)
        record()
        set(history:prev())
      end,
      hist_down = function(self)
        record()
        set(history:next())
      end,
      cmp = function()
        return vim.fn.pumvisible() == 0 and "<c-x><c-u>"
      end,
      cmp_close = function()
        return vim.fn.pumvisible() == 1 and "<c-e>"
      end,
      cmp_accept = function()
        return vim.fn.pumvisible() == 1 and "<c-y>"
      end,
      cmp_select_next = function()
        return vim.fn.pumvisible() == 1 and "<c-n>"
      end,
      cmp_select_prev = function()
        return vim.fn.pumvisible() == 1 and "<c-p>"
      end,
    },
  })

  local parent_zindex = vim.api.nvim_win_get_config(parent_win).zindex
  opts.win.zindex = math.max((parent_zindex or 50) + 1, opts.win.zindex or 50)

  local min_width = opts.win.width or 60
  if opts.expand then
    ---@param self snacks.win
    opts.win.width = function(self)
      local w = type(min_width) == "function" and min_width(self) or min_width --[[@as number]]
      return math.max(w, vim.api.nvim_strwidth(self:text()) + 5)
    end
  end

  local win = Snacks.win(opts.win)
  ctx = { opts = opts, win = win }
  vim.fn.prompt_setprompt(win.buf, "")
  if opts.default then
    vim.api.nvim_buf_set_lines(win.buf, 0, -1, false, { opts.default })
  end

  local function highlight()
    if type(opts.highlight) ~= "function" then
      return
    end
    local text = win:text()
    vim.api.nvim_buf_clear_namespace(win.buf, ns, 0, -1)
    for _, hl in ipairs(opts.highlight(text)) do
      vim.api.nvim_buf_set_extmark(win.buf, ns, 0, hl[1], {
        end_col = hl[2],
        hl_group = hl[3],
        strict = false,
      })
    end
  end

  highlight()

  vim.api.nvim_win_call(win.win, function()
    vim.cmd("startinsert!")
  end)

  vim.fn.prompt_setcallback(win.buf, function(text)
    confirm(text)
    win:close()
  end)
  vim.fn.prompt_setinterrupt(win.buf, function()
    confirm()
    win:close()
  end)

  win:on({ "TextChangedI", "TextChanged" }, function()
    if not win:valid() then
      return
    end
    highlight()
    vim.bo[win.buf].modified = false
    if opts.expand then
      if vim.api.nvim_win_is_valid(parent_win) then
        vim.api.nvim_win_call(parent_win, function()
          win:update()
        end)
      end
      vim.api.nvim_win_call(win.win, function()
        vim.fn.winrestview({ leftcol = 0 })
      end)
    end
  end, { buf = true })
  return win
end

---@param findstart number
---@param base string
---@private
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

function M.enable()
  vim.ui.input = M.input
end

function M.disable()
  vim.ui.input = ui_input
end

---@private
function M.health()
  if Snacks.config.get("input", defaults).enabled then
    if vim.ui.input == M.input then
      Snacks.health.ok("`vim.ui.input` is set to `Snacks.input`")
    else
      Snacks.health.error("`vim.ui.input` is not set to `Snacks.input`")
    end
  end
end

return M
