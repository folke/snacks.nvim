local Actions = require("snacks.gh.actions")
local Api = require("snacks.gh.api")
local Item = require("snacks.gh.item")
local Render = require("snacks.gh.render")

---@class snacks.gh.Buf
---@field buf number
---@field opts snacks.gh.Config
---@field item snacks.gh.api.View
local M = {}
M.__index = M

---@class vim.var_accessor
---@field snacks_gh? { repo: string, type: string, number: number }

---@type table<number, snacks.gh.Buf>
M.attached = {}
local did_setup = false

---@param buf number
---@param item snacks.gh.api.View
function M.new(buf, item)
  local self = setmetatable({}, M)
  self.buf = buf
  self.item = item
  self.opts = vim.deepcopy(Snacks.gh.config())
  self.opts.bo = Snacks.config.merge({}, self.opts.bo, {
    buftype = "acwrite",
    swapfile = false,
    filetype = "markdown.gh",
  })
  vim.b[buf].snacks_gh = {
    repo = item.repo,
    type = item.type,
    number = item.number,
  }
  self:bo()
  self:wo()
  self:keys()
  M.attached[buf] = self
  vim.schedule(function()
    self:render()
  end)
  return self
end

function M:update()
  if not self:valid() then
    return
  end
  self:render({ force = true })
end

function M:keys()
  local actions = Actions.get_actions(self.item)

  ---@param name string
  local function wrap(name)
    local action = actions[name]
    if not action then
      return
    end
    ---@type snacks.gh.Keymap.fn
    return function(item)
      action.action(item, { items = { item } })
    end
  end

  for name, km in pairs(self.opts.keys or {}) do
    if km ~= false then
      local rhs = km[2]
      local desc = km.desc
      local action = type(rhs) == "function" and rhs or type(rhs) == "string" and wrap(rhs) or nil
      if action then
        Snacks.keymap.set(km.mode or "n", km[1], function()
          action(self.item, self)
        end, { buffer = self.buf, desc = desc })
      elseif type(rhs) == "string" and not Actions.actions[rhs] then
        Snacks.notify.error(("Invalid gh buffer keymap action `%s:%s`"):format(name, rhs))
      end
    end
  end
end

function M:valid()
  return self.buf and M.attached[self.buf] == self and vim.api.nvim_buf_is_valid(self.buf)
end

---@param opts? {force?:boolean}
function M:render(opts)
  if not self:valid() then
    return
  end
  opts = opts or {}
  self.item = Api.get(self.item)

  self:bo()
  self:wo()

  local spinner ---@type snacks.util.Spinner?
  local proc = Api.view(self.item, function(it, updated)
    vim.schedule(function()
      if not self:valid() then
        return
      end
      if spinner then
        spinner:stop()
      end
      self.item = it
      if updated then
        Render.render(self.buf, it, self.opts)
        self:keys()
      end
    end)
  end, { force = opts.force })

  -- initial render (is partial if proc is running)
  if Item.is(self.item) then
    Render.render(self.buf, self.item, Snacks.config.merge({}, vim.deepcopy(self.opts), { partial = proc ~= nil }))
  end

  if proc then
    spinner = Snacks.picker.util.spinner(self.buf)
  end
end

function M:bo()
  vim.b[self.buf].snacks_statuscolumn_left = false
  Snacks.util.bo(self.buf, self.opts.bo)
end

function M:wo()
  for _, win in ipairs(vim.fn.win_findbuf(self.buf)) do
    Snacks.util.wo(win, self.opts.wo)
  end
end

---@param buf number
---@param item? snacks.gh.api.View
function M.attach(buf, item)
  M.setup()
  local ret = M.attached[buf]
  if ret then
    ret:update()
    return ret
  end
  if not item then
    local name = vim.api.nvim_buf_get_name(buf)
    local repo, type, number = name:match("^gh://([^/]+/[^/]+)/([^/]+)/(%d+)$")
    if not repo then
      Snacks.notify.error("Invalid gh:// buffer: " .. name)
      return
    end
    item = {
      repo = repo,
      type = type,
      number = number,
    }
  end
  return M.new(buf, item)
end

--@param buf number
function M.detach(buf)
  if not M.attached[buf] then
    return
  end
  M.attached[buf] = nil
end

function M.setup()
  if did_setup then
    return
  end
  did_setup = true
  local group = vim.api.nvim_create_augroup("snacks.gh.buf", { clear = true })

  vim.api.nvim_create_autocmd("BufReadCmd", {
    pattern = "gh://*",
    group = group,
    callback = function(e)
      vim.schedule(function()
        -- schedule since Neovim otherwise runs this in the autocmd window
        M.attach(e.buf)
      end)
    end,
  })

  -- prevent altering the original image file
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    pattern = "gh://*",
    group = group,
    callback = function(e)
      vim.bo[e.buf].modified = false
    end,
  })

  vim.api.nvim_create_autocmd("BufWinEnter", {
    pattern = "gh://*",
    group = group,
    callback = function(e)
      local buf = M.attached[e.buf]
      if buf then
        buf:bo()
        buf:wo()
      end
    end,
  })

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = function(e)
      for _, buf in pairs(M.attached) do
        buf:render()
      end
    end,
  })

  -- detach on buffer delete
  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    pattern = "gh://*",
    group = group,
    callback = function(ev)
      M.detach(ev.buf)
    end,
  })

  -- Keep some empty windows in sessions
  vim.api.nvim_create_autocmd("ExitPre", {
    group = group,
    callback = function()
      local keep = { "markdown.gh" }
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.tbl_contains(keep, vim.bo[buf].filetype) then
          vim.bo[buf].buftype = "" -- set buftype to empty to keep the window
        end
      end
    end,
  })
end

return M
