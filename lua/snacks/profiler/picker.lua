---@class snacks.profiler.picker
local M = {}

---@param opts? snacks.profiler.Pick
function M.open(opts)
  opts = opts or {}

  local picker = opts and opts.picker or Snacks.profiler.config.pick.picker
  -- special case for trouble, since it does its own thing
  if picker == "trouble" then
    return require("trouble").open({ mode = "profiler", params = opts })
  end

  local traces, _, fopts = Snacks.profiler.tracer.find(opts)

  return Snacks.picker({
    title = "Snacks Profiler",
    finder = function()
      local items = {} ---@type snacks.picker.finder.Item[]
      for _, trace in ipairs(traces) do
        items[#items + 1] = {
          text = trace.name,
          file = trace.loc and trace.loc.file,
          pos = trace.loc and { trace.loc.line, 0 },
          item = trace,
        }
      end
      return items
    end,
    format = function(item)
      ---@type snacks.profiler.Trace
      local trace = item.item
      local ret = Snacks.profiler.ui.format(
        Snacks.profiler.ui.badges(trace, {
          badges = Snacks.profiler.config.pick.badges,
          indent = fopts.group == false or fopts.structure,
        }),
        { widths = { 8, 4, 1 } }
      )
      for _, text in ipairs(ret) do
        if text[2] == "Normal" or text[2] == "SnacksProfilerBadgeTrace" then
          text[2] = nil
        end
      end
      return ret
    end,
    preview = function(ctx)
      Snacks.picker.preview.file(ctx)
      Snacks.util.wo(ctx.win, { cursorline = true })
      Snacks.profiler.ui.highlight(
        ctx.buf,
        vim.tbl_extend("force", {}, Snacks.profiler.config.pick.preview, { file = ctx.item.file })
      )
    end,
  })
end

return M
