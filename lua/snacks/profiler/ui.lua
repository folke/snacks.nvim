---@class snacks.profiler.ui
local M = {}

M.highlights = {} ---@type table<string, table<number, snacks.profiler.Trace>>
M.max_time = 0
M.ns = vim.api.nvim_create_namespace("snacks_profiler")
M.shades = 20
M.enabled = true
M.max_time = 0

---@type table<string, fun(entry:snacks.profiler.Trace):snacks.profiler.Badge>
M.badge_formats = {
  time = function(entry)
    local ms = entry.time / 1e6
    return { icon = Snacks.profiler.config.icons.time, text = ("%.2f ms"):format(ms), level = M.get_level(ms, "time") }
  end,
  pct = function(entry)
    local pct = entry.time / M.max_time * 100
    return { icon = Snacks.profiler.config.icons.pct, text = ("%d%%"):format(pct), level = M.get_level(pct, "pct") }
  end,
  count = function(entry)
    local count = entry.count or 1
    return { icon = " ", text = ("%d"):format(count), level = M.get_level(count, "count") }
  end,
  trace = function(entry)
    local field, value = entry.name:match("^(%w+):(.*)$") ---@type string?, string?
    value = field == "file" and vim.fn.fnamemodify(value, ":~:.") or value
    value = field == "require" and ("require(%q)"):format(value) or value
    value = field == "autocmd" and ("autocmd %s"):format(value) or value
    value = Snacks.profiler.config.icons[field] and value or entry.name
    return {
      icon = Snacks.profiler.config.icons[field] or Snacks.profiler.config.icons.fn,
      text = value,
      padding = false,
      level = "Trace",
    }
  end,
}

function M.toggle()
  if M.enabled then
    M.hide()
  else
    M.show()
  end
end

function M.hide()
  assert(M.enabled, "Highlights are not enabled")
  M.enabled = false
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "" then
      vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
    end
  end
end

function M.show()
  assert(not M.enabled, "Highlights are already enabled")
  M.enabled = true
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "" then
      M.highlight(buf, Snacks.profiler.config.highlights)
    end
  end
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = vim.api.nvim_create_augroup("snacks_profiler_highlights", { clear = true }),
    callback = function(ev)
      if M.enabled then
        M.highlight(ev.buf, Snacks.profiler.config.highlights)
      end
    end,
  })
end

---@param trace snacks.profiler.Trace
function M.dump(trace)
  local ret = {}
  ---@diagnostic disable-next-line: no-unknown
  for k, v in pairs(trace) do
    if type(k) == "string" then
      ---@diagnostic disable-next-line: no-unknown
      ret[k] = v
    end
  end
  return ret
end

function M.load()
  M.highlights = {}
  M.max_time = 10 * 1e6
  M.colors()
  local groups = {
    defs = Snacks.profiler.tracer.find({ group = "def", structure = false, sort = false }),
    refs = Snacks.profiler.tracer.find({ group = "ref", structure = false, sort = false }),
  }
  for group, entries in pairs(groups) do
    for _, entry in pairs(entries) do
      local loc = entry.loc
      if loc then
        ---@diagnostic disable-next-line: inject-field
        entry._group = group
        M.max_time = math.max(M.max_time, entry.time)
        M.highlights[loc.file] = M.highlights[loc.file] or {}
        if Snacks.profiler.config.debug and M.highlights[loc.file][loc.line] then
          local old = M.highlights[loc.file][loc.line]
          Snacks.debug.inspect({ group = group, old = M.dump(old), new = M.dump(entry) })
        end
        M.highlights[loc.file][loc.line] = entry
      end
    end
  end
end

function M.get_level(value, t)
  return value > Snacks.profiler.config.thresholds[t][2] and "Error"
    or value > Snacks.profiler.config.thresholds[t][1] and "Warn"
    or "Info"
end

---@param entry snacks.profiler.Trace
---@param opts? { badges?: snacks.profiler.Badge.type[], indent?: boolean }
---@return snacks.profiler.Badge[]
function M.badges(entry, opts)
  opts = opts or {}
  opts.badges = opts.badges or { "time", "pct", "count", "name", "trace" }
  local ret = {} ---@type snacks.profiler.Badge[]
  local done = {} ---@type table<string, boolean>
  local indented = false
  for _, b in ipairs(opts.badges) do
    if b == "trace" or b == "name" then
      local entries = {} ---@type snacks.profiler.Trace[]
      if b == "name" then
        table.insert(entries, entry)
      end
      if b == "trace" then
        vim.list_extend(entries, entry)
      end
      for _, e in ipairs(entries) do
        if not done[e.name] then
          done[e.name] = true
          local badge = M.badge_formats.trace(e)
          if opts.indent and not indented then
            indented = true
            badge.text = ("  "):rep(e.depth) .. badge.text
          end
          table.insert(ret, badge)
        end
      end
    else
      table.insert(ret, M.badge_formats[b](entry))
    end
  end
  return ret
end

---@param badges snacks.profiler.Badge[]
---@param opts? {widths?:number[]}
function M.format(badges, opts)
  local text = {} ---@type string[][]
  text[#text + 1] = { "  ", "Normal" }
  for b, badge in ipairs(badges) do
    local level = badge.level or ""
    local padding = badge.padding ~= false
        and opts
        and opts.widths
        and (opts.widths[b] - vim.api.nvim_strwidth(badge.text))
      or 0
    text[#text + 1] = { badge.icon, "SnacksProfilerIcon" .. level }
    text[#text + 1] = { " " .. (" "):rep(padding) .. badge.text .. " ", "SnacksProfilerBadge" .. level }
    text[#text + 1] = { "  ", "Normal" }
  end
  return text
end

---@param buf number
---@param opts? snacks.profiler.Highlights|{file?:string}
function M.highlight(buf, opts)
  opts = opts or {}
  vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
  local file = Snacks.profiler.loc.norm({ file = opts.file or vim.api.nvim_buf_get_name(buf), line = 0 }).file
  local highlights = M.highlights[file]
  if not highlights then
    return
  end

  local keep = {} ---@type table<number, snacks.profiler.Trace>
  for l, entry in pairs(highlights) do
    if entry.time >= (opts.min_time or 0) then
      keep[l] = entry
    end
  end
  highlights = keep

  local align = opts.align or 80
  local buttons = {} ---@type table<number, snacks.profiler.Badge[]>
  local widths = {} ---@type number[]
  for line, entry in pairs(highlights) do
    buttons[line] = M.badges(entry, opts --[[@as snacks.profiler.Highlights]])
    for b, button in ipairs(buttons[line]) do
      widths[b] = math.max(widths[b] or 0, vim.api.nvim_strwidth(button.text))
    end
  end

  for line, entry in pairs(highlights) do
    local text = M.format(buttons[line], { widths = widths })
    if type(align) == "number" then
      text[#text + 1] = { (" "):rep(vim.o.columns), "Normal" }
    end
    local mmax = math.min(M.max_time, 1e6 * Snacks.profiler.config.highlights.max_shade)
    vim.api.nvim_buf_set_extmark(buf, M.ns, line - 1, 0, {
      hl_mode = "combine",
      virt_text = text,
      virt_text_win_col = type(align) == "number" and align or nil,
      virt_text_pos = align == "right" and "right_align" or align == "left" and "eol" or nil,
      line_hl_group = ("SnacksProfilerHot%02d"):format(
        math.max(math.min(math.floor(entry.time / mmax * M.shades), M.shades), 1)
      ),
    })
  end
end

function M.colors()
  ---@type snacks.util.hl
  local hl_groups = {
    Icon = "SnacksProfilerIconInfo",
    Badge = "SnacksProfilerBadgeInfo",
    IconTrace = "SnacksProfilerIconInfo",
    BadgeTrace = "SnacksProfilerBadgeInfo",
  }
  local fallbacks = { Info = "#0ea5e9", Warn = "#f59e0b", Error = "#dc2626" }
  local bg = Snacks.util.color("Normal", "bg") or "#000000"
  local red = Snacks.util.color("DiagnosticError") or fallbacks.Error
  for _, s in ipairs({ "Info", "Warn", "Error" }) do
    local color = Snacks.util.color("Diagnostic" .. s) or fallbacks[s]
    hl_groups["Icon" .. s] = { fg = color, bg = Snacks.util.blend(color, bg, 0.3) }
    hl_groups["Badge" .. s] = { fg = color, bg = Snacks.util.blend(color, bg, 0.1) }
  end
  for i = 1, M.shades do
    hl_groups[("Hot%02d"):format(i)] = { bg = Snacks.util.blend(red, bg, i / (M.shades + 1)) }
  end
  Snacks.util.set_hl(hl_groups, { prefix = "SnacksProfiler", managed = false, default = true })
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("snacks_profiler_colors", { clear = true }),
    callback = M.colors,
  })
end

return M
