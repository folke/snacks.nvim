---@class snacks.dim
---@overload fun(opts: snacks.dim.Config)
local M = setmetatable({}, {
  __call = function(M, ...)
    return M.enable(...)
  end,
})

M.meta = {
  desc = "Focus on the active scope by dimming the rest",
}

---@class snacks.dim.Config
local defaults = {
  ---@type snacks.scope.Config
  scope = {
    min_size = 5,
    max_size = 20,
    siblings = true,
  },
  -- animate scopes. Enabled by default for Neovim >= 0.10
  -- Works on older versions but has to trigger redraws during animation.
  ---@type snacks.animate.Config|{enabled?: boolean}
  animate = {
    enabled = vim.fn.has("nvim-0.10") == 1,
    easing = "outQuad",
    duration = {
      step = 20, -- ms per step
      total = 300, -- maximum duration
    },
  },
  -- what buffers to dim
  filter = function(buf)
    return vim.g.snacks_dim ~= false and vim.b[buf].snacks_dim ~= false and vim.bo[buf].buftype == ""
  end,
}

M.enabled = false
local ns = vim.api.nvim_create_namespace("snacks_dim")
local scopes ---@type snacks.scope.Listener?
local scopes_anim = {} ---@type table<number, {from:number, to:number, buf:number}>

Snacks.util.set_hl({
  [""] = "DiagnosticUnnecessary",
}, { prefix = "SnacksDim", default = true })

--- Called during every redraw cycle, so it should be fast.
--- Everything that can be cached should be cached.
---@param win number
---@param buf number
---@param top number -- 1-indexed
---@param bottom number -- 1-indexed
---@private
function M.on_win(win, buf, top, bottom)
  local scope = scopes and scopes:get(win)
  if not scope then
    return
  end
  local function add(l)
    vim.api.nvim_buf_set_extmark(buf, ns, l - 1, 0, {
      end_row = l,
      end_col = 0,
      hl_group = "SnacksDim",
      ephemeral = true,
    })
  end
  local animating = Snacks.animate.enabled({ buf = buf, name = "dim" })
  local from = animating and scopes_anim[win] and scopes_anim[win].from or scope.from
  local to = animating and scopes_anim[win] and scopes_anim[win].to or scope.to
  for l = top, math.min(from - 1, bottom) do
    add(l)
  end
  for l = math.max(to + 1, top), bottom do
    add(l)
  end
end

---@param opts? snacks.dim.Config
function M.enable(opts)
  if M.enabled then
    return
  end
  opts = Snacks.config.get("dim", defaults, opts)

  M.enabled = true

  vim.g.snacks_animate_dim = opts.animate.enabled

  -- setup decoration provider
  vim.api.nvim_set_decoration_provider(ns, {
    on_win = function(_, win, buf, top, bottom)
      if M.enabled and opts.filter(buf) then
        M.on_win(win, buf, top + 1, bottom + 1)
      end
    end,
  })

  scopes = scopes
    or Snacks.scope.attach(function(win, buf, scope)
      if not Snacks.animate.enabled({ buf = buf, name = "dim" }) then
        Snacks.util.redraw(win)
      else
        if not (scopes_anim[win] and scopes_anim[win].buf == buf) then
          local info = vim.fn.getwininfo(win)[1]
          scopes_anim[win] = {
            from = info.topline,
            to = info.botline,
            buf = buf,
          }
        end
        if scope == nil then
          return
        end
        Snacks.animate(scopes_anim[win].from, scope.from, function(v)
          if not scopes_anim[win] or not vim.api.nvim_win_is_valid(win) then
            return
          end
          scopes_anim[win].from = v
          Snacks.util.redraw(win)
        end, vim.tbl_extend("keep", { int = true, id = "snacks_dim_from_" .. win, buf = buf }, opts.animate))

        Snacks.animate(scopes_anim[win].to, scope.to, function(v)
          if not scopes_anim[win] or not vim.api.nvim_win_is_valid(win) then
            return
          end
          scopes_anim[win].to = v
          Snacks.util.redraw(win)
        end, vim.tbl_extend("keep", { int = true, id = "snacks_dim_to_" .. win, buf = buf }, opts.animate))
      end
    end, opts.scope)
  if not scopes.enabled then
    scopes:enable()
  end
end

-- Disable dimming
function M.disable()
  if not M.enabled then
    return
  end
  M.enabled = false
  if scopes and scopes.enabled then
    scopes:disable()
  end
  scopes_anim = {}
  vim.cmd([[redraw!]])
end

return M
