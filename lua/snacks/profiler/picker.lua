---@class snacks.profiler.picker
local M = {}

---@param opts? snacks.profiler.Pick
function M.open(opts)
  opts = opts or {}

  local picker = opts and opts.picker or Snacks.profiler.config.pick.picker
  if picker == "auto" then
    if pcall(require, "fzf-lua") then
      picker = "fzf-lua"
    elseif pcall(require, "telescope") then
      picker = "telescope"
    elseif pcall(require, "trouble") then
      picker = "trouble"
    else
      return Snacks.notify.error("No picker found")
    end
  end

  -- special case for trouble, since it does its own thing
  if picker == "trouble" then
    return require("trouble").open({ mode = "profiler", params = opts })
  end

  local traces, _, fopts = Snacks.profiler.tracer.find(opts)

  ---@alias snacks.profiler.Pick.entry {badges:snacks.profiler.Badge[], path:string, line:number, col:number, text:string[][]}|snacks.profiler.Trace
  ---@type snacks.profiler.Pick.entry[]
  local entries = {}
  local widths = {} ---@type number[]
  for _, trace in ipairs(traces) do
    local badges = Snacks.profiler.ui.badges(trace, {
      badges = Snacks.profiler.config.pick.badges,
      indent = fopts.group == false or fopts.structure,
    })
    for b, badge in ipairs(badges) do
      widths[b] = math.max(widths[b] or 0, vim.api.nvim_strwidth(badge.text))
    end
    local loc = trace.loc
    table.insert(
      entries,
      setmetatable({ badges = badges, path = loc and loc.file, line = loc and loc.line, col = 1 }, { __index = trace })
    )
  end
  for _, entry in ipairs(entries) do
    entry.text = Snacks.profiler.ui.format(entry.badges, { widths = widths })
    for _, text in ipairs(entry.text) do
      if text[2] == "Normal" or text[2] == "SnacksProfilerBadgeTrace" then
        text[2] = nil
      end
    end
  end

  if #entries == 0 then
    return Snacks.notify.warn("No traces found")
  end

  if picker == "telescope" then
    M.telescope(entries)
  elseif picker == "fzf-lua" then
    M.fzf_lua(entries)
  else
    return Snacks.notify.error("Not a valid picker `" .. picker .. "`")
  end
end

---@param entries snacks.profiler.Pick.entry[]
function M.telescope(entries)
  local finder = require("telescope.finders").new_table({
    results = entries,
    ---@param entry snacks.profiler.Pick.entry
    entry_maker = function(entry)
      local text, hl = {}, {} ---@type string[], string[][]
      local col = 0
      for _, t in ipairs(entry.text) do
        text[#text + 1] = t[1]
        if t[2] then
          table.insert(hl, { { col, col + #t[1] }, t[2] })
        end
        col = col + #t[1]
      end
      return vim.tbl_extend("force", entry, {
        lnum = entry.line,
        ordinal = entry.name,
        display = function()
          return table.concat(text), hl
        end,
      })
    end,
  })
  local conf = require("telescope.config").values
  local topts = {}
  local previewer = require("telescope.previewers").new_buffer_previewer({
    title = "File Preview",
    define_preview = function(self, entry, _status)
      conf.buffer_previewer_maker(entry.path, self.state.bufnr, {
        bufname = self.state.bufname,
        winid = self.state.winid,
        callback = function(bufnr)
          Snacks.util.wo(self.state.winid, { cursorline = true })
          Snacks.profiler.ui.highlight(
            self.state.bufnr,
            vim.tbl_extend("force", {}, Snacks.profiler.config.pick.preview, { file = entry.path })
          )
          pcall(vim.api.nvim_win_set_cursor, self.state.winid, { entry.lnum, 0 })
          vim.api.nvim_buf_call(bufnr, function()
            vim.cmd("norm! zz")
          end)
        end,
      })
    end,
  })
  require("telescope.pickers")
    .new(topts, {
      results_title = "Snacks Profiler",
      prompt_title = "Filter",
      finder = finder,
      previewer = previewer,
      sorter = conf.generic_sorter(topts),
    })
    :find()
end

---@param entries snacks.profiler.Pick.entry[]
function M.fzf_lua(entries)
  local fzf = require("fzf-lua")
  local builtin = require("fzf-lua.previewer.builtin")
  local previewer = builtin.buffer_or_file:extend()
  function previewer:new(o, fzf_opts, fzf_win)
    previewer.super.new(self, o, fzf_opts, fzf_win)
    setmetatable(self, previewer)
    return self
  end
  function previewer:parse_entry(entry_str)
    local id = tonumber(entry_str:match("^(%d+)") or "0")
    return entries[id] or {}
  end
  function previewer:preview_buf_post(entry, min_winopts)
    builtin.buffer_or_file.preview_buf_post(self, entry, min_winopts)
    Snacks.profiler.ui.highlight(
      self.preview_bufnr,
      vim.tbl_extend("force", {}, Snacks.profiler.config.pick.preview, { file = entry.path })
    )
  end

  local contents = {} ---@type string[]
  for e, entry in ipairs(entries) do
    local display = { e .. " " } ---@type string[]
    for _, text in ipairs(entry.text) do
      display[#display + 1] = text[2] and fzf.utils.ansi_from_hl(text[2], text[1]) or text[1]
    end
    contents[#contents + 1] = table.concat(display)
  end

  require("fzf-lua").fzf_exec(contents, {
    previewer = previewer,
    -- multiline = true,
    actions = {
      -- Use fzf-lua builtin actions or your own handler
      ["default"] = function(selection, fzf_opts)
        fzf.actions.file_edit(
          vim.tbl_map(function(sel)
            local id = tonumber(sel:match("^(%d+)") or "0")
            return entries[id].path .. ":" .. entries[id].line
          end, selection),
          fzf_opts
        )
      end,
    },
    fzf_opts = {
      ["--no-multi"] = "",
      ["--with-nth"] = "2..",
      ["--no-sort"] = true,
    },
  })
end
return M
