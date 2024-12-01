---@class snacks.toggle
---@field opts snacks.toggle.Opts
---@overload fun(... :snacks.toggle.Opts): snacks.toggle
local M = setmetatable({}, {
  __call = function(t, ...)
    return t.new(...)
  end,
})

---@class snacks.toggle.Config
---@field icon? string|{ enabled: string, disabled: string }
---@field color? string|{ enabled: string, disabled: string }
local defaults = {
  map = vim.keymap.set, -- keymap.set function to use
  which_key = true, -- integrate with which-key to show enabled/disabled icons and colors
  notify = true, -- show a notification when toggling
  -- icons for enabled/disabled states
  icon = {
    enabled = " ",
    disabled = " ",
  },
  -- colors for enabled/disabled states
  color = {
    enabled = "green",
    disabled = "yellow",
  },
}

---@class snacks.toggle.Opts: snacks.toggle.Config
---@field name string
---@field get fun():boolean
---@field set fun(state:boolean)

---@param ... snacks.toggle.Opts
---@return snacks.toggle
function M.new(...)
  local self = setmetatable({}, { __index = M })
  self.opts = Snacks.config.get("toggle", defaults, ...) --[[@as snacks.toggle.Opts]]
  return self
end

function M:get()
  local ok, ret = pcall(self.opts.get)
  if not ok then
    Snacks.notify.error({
      "Failed to get state for `" .. self.opts.name .. "`:\n",
      ret --[[@as string]],
    }, { title = self.opts.name, once = true })
    return false
  end
  return ret
end

---@param state boolean
function M:set(state)
  local ok, err = pcall(self.opts.set, state) ---@type boolean, string?
  if not ok then
    Snacks.notify.error({
      "Failed to set state for `" .. self.opts.name .. "`:\n",
      err --[[@as string]],
    }, { title = self.opts.name, once = true })
  end
end

function M:toggle()
  local state = not self:get()
  self:set(state)
  if self.opts.notify then
    Snacks.notify(
      (state and "Enabled" or "Disabled") .. " **" .. self.opts.name .. "**",
      { title = self.opts.name, level = state and vim.log.levels.INFO or vim.log.levels.WARN }
    )
  end
end

---@param keys string
---@param opts? vim.keymap.set.Opts | { mode: string|string[]}
function M:map(keys, opts)
  opts = opts or {}
  local mode = opts.mode or "n"
  opts.mode = nil
  opts.desc = opts.desc or ("Toggle " .. self.opts.name)
  self.opts.map(mode, keys, function()
    self:toggle()
  end, opts)
  if self.opts.which_key and pcall(require, "which-key") then
    self:_wk(keys, mode)
  end
end

function M:_wk(keys, mode)
  require("which-key").add({
    {
      keys,
      mode = mode,
      icon = function()
        local key = self:get() and "enabled" or "disabled"
        return {
          icon = type(self.opts.icon) == "string" and self.opts.icon or self.opts.icon[key],
          color = type(self.opts.color) == "string" and self.opts.color or self.opts.color[key],
        }
      end,
      desc = function()
        return (self:get() and "Disable " or "Enable ") .. self.opts.name
      end,
    },
  })
end

---@param option string
---@param opts? snacks.toggle.Config | {on?: unknown, off?: unknown}
function M.option(option, opts)
  opts = opts or {}
  local on = opts.on == nil and true or opts.on
  local off = opts.off ~= nil and opts.off or false
  return M.new({
    name = option,
    get = function()
      return vim.opt_local[option]:get() == on
    end,
    set = function(state)
      vim.opt_local[option] = state and on or off
    end,
  }, opts)
end

---@param opts? snacks.toggle.Config
function M.treesitter(opts)
  return M.new({
    name = "Treesitter Highlight",
    get = function()
      return vim.b.ts_highlight
    end,
    set = function(state)
      vim.treesitter[state and "start" or "stop"]()
    end,
  }, opts)
end

---@param opts? snacks.toggle.Config
function M.line_number(opts)
  local number, relativenumber = true, true
  return M.new({
    name = "Line Numbers",
    get = function()
      return vim.opt_local.number:get() or vim.opt_local.relativenumber:get()
    end,
    set = function(state)
      if state then
        vim.opt_local.number, vim.opt_local.relativenumber = number, relativenumber
      else
        number, relativenumber = vim.opt_local.number:get(), vim.opt_local.relativenumber:get()
        vim.opt_local.number, vim.opt_local.relativenumber = false, false
      end
    end,
  }, opts)
end

---@param opts? snacks.toggle.Config
function M.inlay_hints(opts)
  return M.new({
    name = "Inlay Hints",
    get = function()
      return vim.lsp.inlay_hint.is_enabled({ bufnr = 0 })
    end,
    set = function(state)
      vim.lsp.inlay_hint.enable(state, { bufnr = 0 })
    end,
  }, opts)
end

---@param opts? snacks.toggle.Config
function M.diagnostics(opts)
  return M.new({
    name = "Diagnostics",
    get = function()
      local enabled = false
      if vim.diagnostic.is_enabled then
        enabled = vim.diagnostic.is_enabled()
      elseif vim.diagnostic.is_disabled then
        enabled = not vim.diagnostic.is_disabled()
      end
      return enabled
    end,
    set = function(state)
      if vim.fn.has("nvim-0.10") == 0 then
        if state then
          pcall(vim.diagnostic.enable)
        else
          pcall(vim.diagnostic.disable)
        end
      else
        vim.diagnostic.enable(state)
      end
    end,
  }, opts)
end

---@private
function M.health()
  local ok = pcall(require, "which-key")
  Snacks.health[ok and "ok" or "warn"](("{which-key} is %s"):format(ok and "installed" or "not installed"))
end

function M.profiler()
  return M.new({
    name = "Profiler",
    get = function()
      return Snacks.profiler.running()
    end,
    set = function(state)
      if state then
        Snacks.profiler.start()
      else
        Snacks.profiler.stop()
      end
    end,
  })
end

function M.profiler_highlights()
  return M.new({
    name = "Profiler Highlights",
    get = function()
      return Snacks.profiler.ui.enabled
    end,
    set = function(state)
      if state then
        Snacks.profiler.ui.show()
      else
        Snacks.profiler.ui.hide()
      end
    end,
  })
end

return M
