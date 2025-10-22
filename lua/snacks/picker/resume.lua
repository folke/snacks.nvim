local M = {}

M.state = {} ---@type table<string, snacks.picker.resume.State>

---@param picker snacks.Picker
function M.add(picker)
  for toggle in pairs(picker.opts.toggles) do
    picker.init_opts[toggle] = picker.opts[toggle]
  end

  local source = picker.opts.source or "custom"

  ---@class snacks.picker.resume.State
  local state = {
    opts = picker.init_opts or {},
    selected = picker:selected({ fallback = false }),
    cursor = picker.list.cursor,
    topline = picker.list.top,
    filter = picker.input.filter,
    added = vim.uv.hrtime(),
    items = source:find("^lsp_") and picker.finder.items or nil,
  }
  state.opts.live = picker.opts.live
  M.state[source] = state
end

---@param state snacks.picker.resume.State
function M._resume(state)
  state.opts.pattern = state.filter.pattern
  state.opts.search = state.filter.search
  if state.items then
    state.opts.finder = function()
      return state.items
    end
  end
  local ret = Snacks.picker.pick(state.opts)
  ret.list:set_selected(state.selected)
  ret.list:update()
  ret.input:update()
  ret.matcher.task:on(
    "done",
    vim.schedule_wrap(function()
      if ret.closed then
        return
      end
      ret.list:view(state.cursor, state.topline)
    end)
  )
  return ret
end

---@param opts? snacks.picker.resume.Opts
---@overload fun(source:string):snacks.Picker?
function M.resume(opts)
  opts = type(opts) == "string" and { source = opts } or opts or {}
  local sources = opts.source and { opts.source } or opts.include or vim.tbl_keys(M.state)
  local states = {} ---@type snacks.picker.resume.State[]

  for _, source in ipairs(sources) do
    if M.state[source] and not vim.tbl_contains(opts.exclude or {}, source) then
      states[#states + 1] = M.state[source]
    end
  end

  table.sort(states, function(a, b)
    return a.added > b.added
  end)

  local last = states[1]

  if not last then
    if opts.source then
      return Snacks.picker.pick(opts.source)
    end
    Snacks.notify.error("No picker to resume")
    Snacks.picker.pickers()
    return
  end
  return M._resume(last)
end

return M
