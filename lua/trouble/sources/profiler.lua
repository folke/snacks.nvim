---@module 'trouble'
---@diagnostic disable: inject-field
local Item = require("trouble.item")

---@type trouble.Source
local M = {}

---@diagnostic disable-next-line: missing-fields
M.config = {
  formatters = {
    badges = function(ctx)
      local trace = ctx.item.item ---@type snacks.profiler.Trace
      local badges = Snacks.profiler.ui.badges(trace, { badges = { "time", "count" } })
      local text = Snacks.profiler.ui.format(badges)
      return vim.tbl_map(function(t)
        return { text = t[1], hl = t[2] }
      end, text)
    end,
  },
  modes = {
    profiler = {
      events = { { event = "User", pattern = "SnacksProfilerLoaded" } },
      source = "profiler",
      groups = {
        -- { "tag", format = "{todo_icon} {tag}" },
        -- { "directory" },
        { "loc.plugin", format = "{file_icon} {loc.plugin} {count}" },
      },
      -- sort = { { buf = 0 }, "filename", "pos", "name" },
      sort = { "-time" },
      format = "{name} {badges} {pos}",
    },
  },
}

function M.preview(item, ctx)
  Snacks.profiler.ui.highlight(ctx.buf, { file = item.item.loc.file })
end

function M.get(cb, ctx)
  ---@type snacks.profiler.Find
  local opts = vim.tbl_deep_extend(
    "force",
    { group = "name", structure = true },
    type(ctx.opts.params) == "table" and ctx.opts.params or {}
  )
  local _, node = Snacks.profiler.find(opts)
  local items = {} ---@type trouble.Item[]
  local id = 0

  ---@param n snacks.profiler.Node
  local function add(n)
    if n.trace.def then
      id = id + 1
      local loc = n.trace.def
      local item = Item.new({
        id = id,
        pos = { n.trace.def.line, 0 },
        text = n.trace.name,
        filename = loc and loc.file,
        item = n.trace,
        source = "profiler",
      })
      items[#items + 1] = item
      for _, child in pairs(n.children) do
        item:add_child(add(child))
      end
      return item
    end
  end

  for _, child in pairs(node.children or {}) do
    add(child)
  end
  cb(items)
end

return M
