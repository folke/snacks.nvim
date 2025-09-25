---@class snacks.indent
local M = {}

M.meta = {
  desc = "Indent guides and scopes",
}

M.enabled = false

---@class snacks.indent.Config
---@field enabled? boolean
local defaults = {
  indent = {
    priority = 1,
    enabled = true, -- enable indent guides
    char = "│",
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
  -- animate scopes. Enabled by default for Neovim >= 0.10
  -- Works on older versions but has to trigger redraws during animation.
  ---@class snacks.indent.animate: snacks.animate.Config
  ---@field enabled? boolean
  --- * out: animate outwards from the cursor
  --- * up: animate upwards from the cursor
  --- * down: animate downwards from the cursor
  --- * up_down: animate up or down based on the cursor position
  ---@field style? "out"|"up_down"|"down"|"up"
  animate = {
    enabled = vim.fn.has("nvim-0.10") == 1,
    style = "out",
    easing = "linear",
    duration = {
      step = 20, -- ms per step
      total = 500, -- maximum duration
    },
  },
  ---@class snacks.indent.Scope.Config: snacks.scope.Config
  scope = {
    enabled = true, -- enable highlighting the current scope
    priority = 200,
    char = "│",
    underline = false, -- underline the start of the scope
    only_current = false, -- only show scope in the current window
    hl = "SnacksIndentScope", ---@type string|string[] hl group for scopes
  },
  chunk = {
    -- when enabled, scopes will be rendered as chunks, except for the
    -- top-level scope which will be rendered as a scope.
    enabled = false,
    -- only show chunk scopes in the current window
    only_current = false,
    priority = 200,
    hl = "SnacksIndentChunk", ---@type string|string[] hl group for chunk scopes
    char = {
      corner_top = "┌",
      corner_bottom = "└",
      -- corner_top = "╭",
      -- corner_bottom = "╰",
      horizontal = "─",
      vertical = "│",
      arrow = ">",
    },
  },
  -- filter for buffers to enable indent guides
  filter = function(buf)
    return vim.g.snacks_indent ~= false and vim.b[buf].snacks_indent ~= false and vim.bo[buf].buftype == ""
  end,
  debug = false,
}

---@class snacks.indent.Scope: snacks.scope.Scope
---@field win number
---@field step? number
---@field animate? {from: number, to: number}

local config = Snacks.config.get("scope", defaults)
local ns = vim.api.nvim_create_namespace("snacks_indent")
local cache_extmarks = {} ---@type table<string, vim.api.keyset.set_extmark[]>
local debug_timer = assert((vim.uv or vim.loop).new_timer())
local cache_underline = {} ---@type table<string, boolean>
local has_repeat_lb = vim.fn.has("nvim-0.10.0") == 1
local states = {} ---@type table<number, snacks.indent.State>
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
  Chunk = "SnacksIndentScope",
  ["1"] = "DiagnosticInfo",
  ["2"] = "DiagnosticHint",
  ["3"] = "DiagnosticWarn",
  ["4"] = "DiagnosticError",
  ["5"] = "DiagnosticInfo",
  ["6"] = "DiagnosticHint",
  ["7"] = "DiagnosticWarn",
  ["8"] = "DiagnosticError",
}, { prefix = "SnacksIndent", default = true })

---@param level number
---@param hl string|string[]
local function get_hl(level, hl)
  return type(hl) == "string" and hl or hl[(level - 1) % #hl + 1]
end

---@param hl string
local function get_underline_hl(hl)
  local ret = "SnacksIndentUnderline_" .. hl
  if not cache_underline[hl] then
    local fg = Snacks.util.color(hl, "fg")
    vim.api.nvim_set_hl(0, ret, { sp = fg, underline = true })
    cache_underline[hl] = true
  end
  return ret
end

--- Get the virtual text for the indent guide with
--- the given indent level, left column and shiftwidth
---@param indent number
---@param state snacks.indent.State
local function get_extmarks(indent, state)
  local key = indent
    .. ":"
    .. state.leftcol
    .. ":"
    .. state.shiftwidth
    .. ":"
    .. state.indent_offset
    .. ":"
    .. (state.breakindent and "bi" or "")
  if cache_extmarks[key] then
    return cache_extmarks[key]
  end
  stats.extmarks = stats.extmarks + 1

  local sw = state.shiftwidth
  indent = math.floor(indent / sw) -- full visible indents
  local offset = math.max(math.floor(state.indent_offset / sw), 0) -- offset for the scope
  cache_extmarks[key] = {}

  for i = 1 + offset, indent do
    local col = (i - 1) * sw - state.leftcol
    if col >= 0 then
      table.insert(cache_extmarks[key], {
        virt_text = { { config.indent.char, get_hl(i, config.indent.hl) } },
        virt_text_pos = "overlay",
        virt_text_win_col = col,
        hl_mode = "combine",
        priority = config.indent.priority,
        ephemeral = true,
        virt_text_repeat_linebreak = has_repeat_lb and state.breakindent or nil,
      })
    end
  end
  return cache_extmarks[key]
end

---@param win number
---@param buf number
---@param top number
---@param bottom number
local function get_state(win, buf, top, bottom)
  local prev, changedtick = states[win], vim.b[buf].changedtick ---@type snacks.indent.State?, number
  if not (prev and prev.buf == buf and prev.changedtick == changedtick) then
    prev = nil
  end
  ---@class snacks.indent.State
  ---@field indents table<number, number>
  ---@field blanks table<number, boolean>
  local state = {
    win = win,
    buf = buf,
    changedtick = changedtick,
    is_current = win == vim.api.nvim_get_current_win(),
    top = top,
    bottom = bottom,
    leftcol = vim.api.nvim_buf_call(buf, vim.fn.winsaveview).leftcol --[[@as number]],
    shiftwidth = vim.bo[buf].shiftwidth,
    indents = prev and prev.indents or { [0] = 0 },
    blanks = prev and prev.blanks or {},
    indent_offset = 0, -- the start column of the indent guides
    breakindent = vim.wo[win].breakindent and vim.wo[win].wrap,
  }
  state.shiftwidth = state.shiftwidth == 0 and vim.bo[buf].tabstop or state.shiftwidth
  states[win] = state
  return state
end

function M.debug_win()
  Snacks.debug.inspect(states[vim.api.nvim_get_current_win()])
end

--- Called during every redraw cycle, so it should be fast.
--- Everything that can be cached should be cached.
---@param win number
---@param buf number
---@param top number -- 1-indexed
---@param bottom number -- 1-indexed
---@private
function M.on_win(win, buf, top, bottom)
  local state = get_state(win, buf, top, bottom)

  local scope = scopes and scopes:get(win) --[[@as snacks.indent.Scope?]]
  vim.api.nvim_buf_call(buf, function()
    if scope and vim.fn.foldclosed(scope.from) ~= -1 then
      scope = nil
    end
  end)

  -- adjust top and bottom if only_scope is enabled
  if config.indent.only_scope then
    if not scope then
      return
    end
    state.indent_offset = scope.indent or 0
    state.top = math.max(state.top, scope.from)
    state.bottom = math.min(state.bottom, scope.to)
  end

  local show_indent = config.indent.enabled and (not config.indent.only_current or state.is_current)
  local show_scope = config.scope.enabled and (not config.scope.only_current or state.is_current)
  local show_chunk = config.chunk.enabled and (not config.chunk.only_current or state.is_current)

  -- Calculate and render indents
  local indents = state.indents
  vim.api.nvim_buf_call(buf, function()
    local parent_indent, current_indent ---@type number, number
    for l = state.top, state.bottom do
      local indent = indents[l]
      if not indent then
        stats.indents = stats.indents + 1
        local next = vim.fn.nextnonblank(l)
        -- Indent for a blank line is the minimum of the previous and next non-blank line.
        -- If the previous and next non-blank lines have different indents, add shiftwidth.
        if next ~= l then
          state.blanks[l] = true
          local prev = vim.fn.prevnonblank(l)
          indents[prev] = indents[prev] or vim.fn.indent(prev)
          indents[next] = indents[next] or vim.fn.indent(next)
          indent = math.min(indents[prev], indents[next])
          if indents[prev] ~= indents[next] and indent > 0 then
            indent = indent + state.shiftwidth
          end
        else
          indent = vim.fn.indent(l)
        end
        indents[l] = indent
      end
      if indent ~= current_indent then
        parent_indent = current_indent or indent
        current_indent = indent
      end
      indent = math.min(indent, parent_indent + state.shiftwidth)
      local extmarks = show_indent and indent > 0 and get_extmarks(indent, state)
      for _, opts in ipairs(extmarks or {}) do
        vim.api.nvim_buf_set_extmark(buf, ns, l - 1, 0, opts)
      end
    end
  end)

  -- Render scope
  if scope and (scope:size() > 1 or vim.g.snacks_indent_overlap) then
    show_chunk = show_chunk and (scope.indent or 0) >= state.shiftwidth
    if show_chunk then
      M.render_chunk(scope, state)
    elseif show_scope then
      M.render_scope(scope, state)
    end
  end
end

---@param scope snacks.indent.Scope
---@param state snacks.indent.State
---@return number from, number to
local function bounds(scope, state)
  local from, to = scope.from, scope.to
  if scope.animate then
    from = math.max(scope.animate.from, scope.from)
    to = math.min(scope.animate.to, scope.to)
  end
  from = math.max(from, state.top)
  to = math.min(to, state.bottom)
  return from, to
end

--- Render the scope overlappping the given range
---@param scope snacks.indent.Scope
---@param state snacks.indent.State
---@private
function M.render_scope(scope, state)
  local indent = (scope.indent or 2)
  local hl = get_hl(math.floor(scope.indent / state.shiftwidth) + 1, config.scope.hl)
  local from, to = bounds(scope, state)
  local col = indent - state.leftcol

  if config.scope.underline and scope.from == from then
    vim.api.nvim_buf_set_extmark(scope.buf, ns, scope.from - 1, math.max(col, 0), {
      end_col = #vim.api.nvim_buf_get_lines(scope.buf, scope.from - 1, scope.from, false)[1],
      hl_group = get_underline_hl(hl),
      hl_mode = "combine",
      priority = config.scope.priority + 1,
      strict = false,
      ephemeral = true,
    })
  end

  if col < 0 then -- scope is hidden
    return
  end

  for l = from, to do
    local i = state.indents[l]
    if (i and i > indent) or vim.g.snacks_indent_overlap or state.blanks[l] then
      vim.api.nvim_buf_set_extmark(scope.buf, ns, l - 1, 0, {
        virt_text = { { config.scope.char, hl } },
        virt_text_pos = "overlay",
        virt_text_win_col = col,
        hl_mode = "combine",
        priority = config.scope.priority,
        strict = false,
        ephemeral = true,
        virt_text_repeat_linebreak = has_repeat_lb and state.breakindent or nil,
      })
    end
  end
end

--- Render the scope overlappping the given range
---@param scope snacks.indent.Scope
---@param state snacks.indent.State
---@private
function M.render_chunk(scope, state)
  local indent = (scope.indent or 2)
  local col = indent - state.leftcol - state.shiftwidth
  if col < 0 then -- scope is hidden
    return
  end
  local from, to = bounds(scope, state)
  local hl = get_hl(math.floor(scope.indent / state.shiftwidth) + 1, config.chunk.hl)
  local char = config.chunk.char

  ---@param l number
  ---@param line string
  ---@param repeat_indent? boolean
  local function add(l, line, repeat_indent)
    vim.api.nvim_buf_set_extmark(scope.buf, ns, l - 1, 0, {
      virt_text = { { line, hl } },
      virt_text_pos = "overlay",
      virt_text_win_col = col,
      hl_mode = "combine",
      priority = config.chunk.priority,
      strict = false,
      virt_text_repeat_linebreak = has_repeat_lb and repeat_indent or nil,
      ephemeral = true,
    })
  end

  for l = from, to do
    local i = state.indents[l] - state.leftcol
    if l == scope.from then -- top line
      if state.breakindent then
        add(l, char.vertical, true)
      end
      add(l, char.corner_top .. (char.horizontal):rep(i - col - 1))
    elseif l == scope.to then -- bottom line
      add(l, char.corner_bottom .. (char.horizontal):rep(i - col - 2) .. char.arrow)
    elseif i and i > col then -- middle line
      add(l, char.vertical, state.breakindent)
    end
  end
end

---@param scope snacks.indent.Scope
---@param value number
---@param prev? number
local function step(scope, value, prev)
  if not vim.api.nvim_win_is_valid(scope.win) then
    return
  end
  prev = prev or 0
  local cursor = vim.api.nvim_win_get_cursor(scope.win)
  local dt = math.abs(scope.from - cursor[1])
  local db = math.abs(scope.to - cursor[1])
  local style = config.animate.style == "up_down" and (dt < db and "down" or "up") or config.animate.style
  if style == "down" then
    scope.animate = { from = scope.from, to = scope.from + value }
  elseif style == "up" then
    scope.animate = { from = scope.to - value, to = scope.to }
  elseif style == "out" then
    local line = math.min(math.max(scope.from, cursor[1]), scope.to)
    scope.animate = {
      from = math.max(scope.from, line - value),
      to = math.min(scope.to, line + value),
    }
  else
    Snacks.notify.error("Invalid animate style: " .. style, { title = "Snacks Indent", once = true })
  end
  Snacks.util.redraw_range(scope.win, scope.animate.from, scope.animate.to)
end

-- Called when the scope changes
---@param win number
---@param buf number
---@param scope snacks.indent.Scope?
---@param prev snacks.indent.Scope?
---@private
function M.on_scope(win, buf, scope, prev)
  stats.scope = stats.scope + 1
  if scope then
    scope.win = win
    local animate = Snacks.animate.enabled({ buf = buf, name = "indent" })

    vim.api.nvim_buf_call(buf, function()
      -- skip animation if new lines have been added before or inside the scope
      if prev and (vim.fn.nextnonblank(prev.from) == scope.from) then
        animate = false
      end
    end)

    if animate then
      step(scope, 0)
      Snacks.animate(
        0,
        scope.to - scope.from,
        function(value, ctx)
          if scopes and scopes:get(win) ~= scope then
            return
          end
          step(scope, value, ctx.prev)
        end,
        vim.tbl_extend("keep", {
          int = true,
          id = "indent_scope_" .. win,
          buf = buf,
        }, config.animate)
      )
    else
      Snacks.util.redraw_range(win, scope.from, scope.to)
    end
  end
  if prev then -- clear previous scope
    Snacks.util.redraw_range(win, prev.from, prev.to)
  end
end

---@private
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

  vim.g.snacks_animate_indent = config.animate.enabled

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

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = function()
      cache_underline = {}
    end,
  })

  -- cleanup cache
  vim.api.nvim_create_autocmd({ "WinClosed", "BufDelete", "BufWipeout" }, {
    group = group,
    callback = function()
      for win in pairs(states) do
        if not vim.api.nvim_win_is_valid(win) then
          states[win] = nil
        end
      end
    end,
  })

  -- redraw when shiftwidth changes
  -- vim.api.nvim_create_autocmd("OptionSet", {
  --   group = group,
  --   pattern = { "shiftwidth", "listchars", "list" },
  --   callback = vim.schedule_wrap(function()
  --     vim.cmd([[redraw!]])
  --   end),
  -- })
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
  states = {}
  stats = { indents = 0, extmarks = 0, scope = 0 }
  vim.cmd([[redraw!]])
end

return M
