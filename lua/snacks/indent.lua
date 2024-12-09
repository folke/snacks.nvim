---@class snacks.indent
local M = {}

M.enabled = false
M.animating = false

---@class snacks.indent.Config
---@field enabled? boolean
local defaults = {
  indent = {
    char = "│",
    blank = " ",
    -- blank = "∙",
    only_scope = false, -- only show indent guides of the scope
    only_current = false, -- only show indent guides in the current window
    hl = "SnacksIndent", ---@type string|string[] hl groups for indent guides
    -- can be a list of hl groups to cycle through
    -- hl = {
    --     "SnacksIndent1",
    --     "SnacksIndent2",
    --     "SnacksIndent3",
    --     "SnacksIndent4",
    --     "SnacksIndent5",
    --     "SnacksIndent6",
    --     "SnacksIndent7",
    --     "SnacksIndent8",
    -- },
  },
  ---@class snacks.indent.Scope.Config: snacks.scope.Config
  scope = {
    -- animate scopes. Enabled by default for Neovim >= 0.10
    -- Works on older versions but has to trigger redraws during animation.
    ---@type snacks.animate.Config|{enabled?: boolean}
    animate = {
      enabled = vim.fn.has("nvim-0.10") == 1,
      easing = "linear",
      duration = {
        step = 20, -- ms per step
        total = 500, -- maximum duration
      },
    },
    char = "│",
    underline = false, -- underline the start of the scope
    only_current = false, -- only show scope in the current window
    hl = "SnacksIndentScope", ---@type string|string[] hl group for scopes
  },
  blank = {
    char = " ",
    -- char = "·",
    hl = "SnacksIndentBlank", ---@type string|string[] hl group for blank spaces
  },
  -- filter for buffers to enable indent guides
  filter = function(buf)
    return vim.g.snacks_indent ~= false and vim.b[buf].snacks_indent ~= false and vim.bo[buf].buftype == ""
  end,
  priority = 200,
  debug = false,
}

---@class snacks.indent.Scope: snacks.scope.Scope
---@field win number
---@field step? number

local config = Snacks.config.get("scope", defaults)
local ns = vim.api.nvim_create_namespace("snacks_indent")
local cache_indents = {} ---@type table<number, {changedtick:number, indents:number[]}>
local cache_extmarks = {} ---@type table<string, vim.api.keyset.set_extmark|false>
local debug_timer = assert((vim.uv or vim.loop).new_timer())
local scopes ---@type snacks.scope.Listener?
local stats = {
  indents = 0,
  extmarks = 0,
  scope = 0,
}

Snacks.util.set_hl({
  [""] = "NonText",
  Blank = "SnacksIndent",
  Scope = "Special",
  ScopeUnderLine = { underline = true, sp = Snacks.util.color("Special", "fg") },
  ["1"] = "DiagnosticInfo",
  ["2"] = "DiagnosticHint",
  ["3"] = "DiagnosticWarn",
  ["4"] = "DiagnosticError",
  ["5"] = "DiagnosticInfo",
  ["6"] = "DiagnosticHint",
  ["7"] = "DiagnosticWarn",
  ["8"] = "DiagnosticError",
}, { prefix = "SnacksIndent" })

---@param level number
---@param hl string|string[]
local function get_hl(level, hl)
  return type(hl) == "string" and hl or hl[(level - 1) % #hl + 1]
end

--- Get the virtual text for the indent guide with
--- the given indent level, left column and shiftwidth
---@param indent number
---@param ctx snacks.indent.ctx
local function get_extmark(indent, ctx)
  local key = indent .. ":" .. ctx.leftcol .. ":" .. ctx.shiftwidth
  if cache_extmarks[key] ~= nil then
    return cache_extmarks[key]
  end
  stats.extmarks = stats.extmarks + 1

  local sw = ctx.shiftwidth
  indent = math.floor(indent / sw) * sw -- align to shiftwidth
  indent = indent - ctx.leftcol -- adjust for visible indents
  local rem = indent % sw -- remaining spaces of the first partially visible indent
  indent = math.floor(indent / sw) -- full visible indents

  -- hide if indent is 0 and no remaining spaces
  if indent < 1 and rem == 0 then
    cache_extmarks[key] = false
    return false
  end

  local hidden = math.ceil(ctx.leftcol / sw) -- level of the last hidden indent
  local blank = config.indent.blank:rep(sw - vim.api.nvim_strwidth(config.indent.char))

  local text = {} ---@type string[][]
  text[1] = rem > 0 and { (config.indent.blank):rep(rem), get_hl(hidden, config.blank.hl) } or nil

  for i = 1, indent do
    text[#text + 1] = { config.indent.char, get_hl(i + hidden, config.indent.hl) }
    text[#text + 1] = { blank, get_hl(i + hidden, config.blank.hl) }
  end

  cache_extmarks[key] = {
    virt_text = text,
    virt_text_pos = "overlay",
    hl_mode = "combine",
    priority = config.priority,
    ephemeral = true,
  }
  return cache_extmarks[key]
end

--- Called during every redraw cycle, so it should be fast.
--- Everything that can be cached should be cached.
---@param win number
---@param buf number
---@param top number -- 1-indexed
---@param bottom number -- 1-indexed
function M.on_win(win, buf, top, bottom)
  cache_indents[buf] = cache_indents[buf]
      and cache_indents[buf].changedtick == vim.b[buf].changedtick
      and cache_indents[buf]
    or { changedtick = vim.b[buf].changedtick, indents = { [0] = 0 } }

  local scope = scopes and scopes:get(win) --[[@as snacks.indent.Scope?]]
  local indent_col = 0 -- the start column of the indent guides

  -- adjust top and bottom if only_scope is enabled
  if config.indent.only_scope then
    if not scope then
      return
    end
    indent_col = scope.indent or 0
    top = math.max(top, scope.from)
    bottom = math.min(bottom, scope.to)
  end

  ---@class snacks.indent.ctx
  local ctx = {
    is_current = win == vim.api.nvim_get_current_win(),
    top = top,
    bottom = bottom,
    leftcol = vim.api.nvim_buf_call(buf, vim.fn.winsaveview).leftcol --[[@as number]],
    shiftwidth = vim.bo[buf].shiftwidth,
    indents = cache_indents[buf].indents,
  }

  local show_indent = not config.indent.only_current or ctx.is_current
  local show_scope = not config.scope.only_current or ctx.is_current

  -- Calculate and render indents
  local indents = cache_indents[buf].indents
  vim.api.nvim_buf_call(buf, function()
    for l = top, bottom do
      local indent = indents[l]
      if not indent then
        stats.indents = stats.indents + 1
        local next = vim.fn.nextnonblank(l)
        -- Indent for a blank line is the minimum of the previous and next non-blank line
        if next ~= l then
          local prev = vim.fn.prevnonblank(l)
          indents[prev] = indents[prev] or vim.fn.indent(prev)
          indents[next] = indents[next] or vim.fn.indent(next)
          indent = math.min(indents[prev], indents[next])
        else
          indent = vim.fn.indent(l)
        end
        indents[l] = indent
      end
      local opts = show_indent and indent > 0 and get_extmark(indent - indent_col, ctx)
      if opts then
        vim.api.nvim_buf_set_extmark(buf, ns, l - 1, indent_col, opts)
      end
    end
  end)

  -- Render scope
  if show_scope and scope then
    M.render(scope, ctx)
  end
end

--- Render the scope overlappping the given range
---@param scope snacks.indent.Scope
---@param ctx snacks.indent.ctx
function M.render(scope, ctx)
  local indent = (scope.indent or 2)
  local col = indent - ctx.leftcol
  if col < 0 then -- scope is hidden
    return
  end
  if config.scope.underline and scope.from >= ctx.top and scope.from <= ctx.bottom and scope:size() > 1 then
    vim.api.nvim_buf_set_extmark(scope.buf, ns, scope.from - 1, col, {
      end_col = #vim.api.nvim_buf_get_lines(scope.buf, scope.from - 1, scope.from, false)[1],
      hl_group = "SnacksIndentScopeUnderLine",
      hl_mode = "combine",
      priority = config.priority + 1,
      strict = false,
      ephemeral = true,
    })
  end
  local to = M.animating and scope.step or scope.to
  for l = math.max(scope.from, ctx.top), math.min(to, ctx.bottom) do
    local i = ctx.indents[l]
    if i and i > indent then
      vim.api.nvim_buf_set_extmark(scope.buf, ns, l - 1, 0, {
        virt_text = { { config.scope.char, get_hl(scope.indent + 1, config.scope.hl) } },
        virt_text_pos = "overlay",
        virt_text_win_col = col,
        hl_mode = "combine",
        priority = config.priority + 1,
        strict = false,
        ephemeral = true,
      })
    end
  end
end

-- Animate scope changes
function M.animate()
  M.animating = not M.animating
end

-- Called when the scope changes
---@param win number
---@param _buf number
---@param scope snacks.indent.Scope?
---@param prev snacks.indent.Scope?
function M.on_scope(win, _buf, scope, prev)
  stats.scope = stats.scope + 1
  if prev then -- clear previous scope
    Snacks.util.redraw_range(win, prev.from, prev.to)
  end
  if scope then
    scope.step = scope.from
    if M.animating then
      Snacks.animate(
        scope.from,
        scope.to,
        function(value, ctx)
          if scopes and scopes:get(win) ~= scope then
            return
          end
          scope.step = value
          Snacks.util.redraw_range(win, math.min(ctx.prev, value), math.max(ctx.prev, value))
        end,
        vim.tbl_extend("keep", {
          int = true,
          id = "indent_scope_" .. win,
        }, config.scope.animate)
      )
    end
    Snacks.util.redraw_range(win, scope.from, M.animating and scope.from + 1 or scope.to)
  end
end

function M.debug()
  if debug_timer:is_active() then
    debug_timer:stop()
    return
  end
  local last = {}
  debug_timer:start(50, 50, function()
    if not vim.deep_equal(stats, last) then
      last = vim.deepcopy(stats)
      Snacks.notify(vim.inspect(stats), { ft = "lua", id = "snacks_indent_debug", title = "Snacks Indent Debug" })
    end
  end)
end

--- Enable indent guides
function M.enable()
  if M.enabled then
    return
  end
  config = Snacks.config.get("indent", defaults)

  if config.debug then
    M.debug()
  end

  if config.scope.animate.enabled then
    M.animate()
  end

  M.enabled = true

  -- setup decoration provider
  vim.api.nvim_set_decoration_provider(ns, {
    on_win = function(_, win, buf, top, bottom)
      if M.enabled and config.filter(buf) then
        M.on_win(win, buf, top + 1, bottom + 1)
      end
    end,
  })

  -- Listen for scope changes
  scopes = scopes or Snacks.scope.attach(M.on_scope, config.scope)
  if not scopes.enabled then
    scopes:enable()
  end

  local group = vim.api.nvim_create_augroup("snacks_indent", { clear = true })

  -- cleanup cache
  vim.api.nvim_create_autocmd({ "WinClosed", "BufDelete", "BufWipeout" }, {
    group = group,
    callback = function()
      for buf in pairs(cache_indents) do
        if not vim.api.nvim_buf_is_valid(buf) then
          cache_indents[buf] = nil
        end
      end
    end,
  })

  -- redraw when shiftwidth changes
  vim.api.nvim_create_autocmd("OptionSet", {
    group = group,
    pattern = { "shiftwidth" },
    callback = vim.schedule_wrap(function()
      vim.cmd([[redraw!]])
    end),
  })
end

-- Disable indent guides
function M.disable()
  if not M.enabled then
    return
  end
  M.enabled = false
  if scopes then
    scopes:disable()
  end
  vim.api.nvim_del_augroup_by_name("snacks_indent")
  debug_timer:stop()
  cache_indents = {}
  stats = { indents = 0, extmarks = 0, scope = 0 }
  vim.cmd([[redraw!]])
end

return M
