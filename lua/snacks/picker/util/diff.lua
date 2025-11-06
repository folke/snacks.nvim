local M = {}

---@class snacks.diff.Config
---@field max_hunk_lines? number only show last N lines of each hunk (used by GitHub PRs)
---@field hunk_header? boolean whether to show hunk header (default: true)
---@field ft? "diff" | "git"

---@param ... string
local function diff_linenr(...)
  local fg = Snacks.util.color(vim.list_extend({ ... }, { "NormalFloat", "Normal" }))
  local bg = Snacks.util.color(vim.list_extend({ ... }, { "NormalFloat", "Normal" }), "bg")
  bg = bg or vim.o.background == "dark" and "#1e1e1e" or "#f5f5f5"
  fg = fg or vim.o.background == "dark" and "#f5f5f5" or "#1e1e1e"
  return {
    fg = fg,
    bg = Snacks.util.blend(fg, bg, 0.1),
  }
end

local CONFLICT_MARKERS = { "<<<<<<<", "=======", ">>>>>>>", "|||||||" }
require("snacks.picker") -- ensure picker hl groups are available

Snacks.util.set_hl({
  DiffHeader = "DiagnosticVirtualTextInfo",
  DiffAdd = "DiffAdd",
  DiffDelete = "DiffDelete",
  HunkHeader = "Normal",
  DiffContext = "DiffChange",
  DiffConflict = "DiagnosticVirtualTextWarn",
  DiffAddLineNr = diff_linenr("DiffAdd"),
  DiffLabel = "@property",
  DiffDeleteLineNr = diff_linenr("DiffDelete"),
  DiffContextLineNr = diff_linenr("DiffChange"),
  DiffConflictLineNr = diff_linenr("DiagnosticVirtualTextWarn"),
}, { default = true, prefix = "Snacks" })

---@param diff string|string[]|snacks.picker.Diff
function M.get_diff(diff)
  if type(diff) == "string" then
    diff = vim.split(diff, "\n", { plain = true })
  end
  ---@cast diff snacks.picker.Diff|string[]
  if type(diff[1]) == "string" then
    diff = require("snacks.picker.source.diff").parse(diff)
  end
  ---@cast diff snacks.picker.Diff
  return diff
end

---@param buf number
---@param ns number
---@param diff string|string[]|snacks.picker.Diff
---@param opts? snacks.diff.Config
function M.render(buf, ns, diff, opts)
  diff = M.get_diff(diff)
  local ret = M.format(diff, opts)
  return Snacks.picker.highlight.render(buf, ns, ret)
end

---@param diff string|string[]|snacks.picker.Diff
---@param opts? snacks.diff.Config
function M.format(diff, opts)
  diff = M.get_diff(diff)
  local ret = {} ---@type snacks.picker.Highlight[][]
  vim.list_extend(ret, M.format_header(diff, opts))
  for _, block in ipairs(diff.blocks) do
    vim.list_extend(ret, M.format_block(block, opts))
  end
  return ret
end

---@param diff snacks.picker.Diff
---@param opts? snacks.diff.Config
function M.format_header(diff, opts)
  if #(diff.header or {}) == 0 then
    return {}
  end
  local popts = Snacks.picker.config.get({})
  opts = opts or {}
  local ret = {} ---@type snacks.picker.Highlight[][]
  local msg = {} ---@type string[]
  for _, line in ipairs(diff.header or {}) do
    local hash = line:match("^commit%s+(%S+)$")
    if hash then
      ret[#ret + 1] = {
        { "Commit", "SnacksDiffLabel" },
        { ": ", "SnacksPickerDelim" },
        { popts.icons.git.commit, "SnacksPickerGitCommit" },
        { hash:sub(1, 8), "SnacksPickerGitCommit" },
      }
    else
      local label, value = line:match("^(%S+):%s*(.-)%s*$")
      if label and value then
        ret[#ret + 1] = {
          { label, "SnacksDiffLabel" },
          { ": ", "SnacksPickerDelim" },
          { value, "SnacksPickerGit" .. label },
        }
      elseif line:match("^    ") then
        msg[#msg + 1] = line:match("^    (.-)%s*$")
      else
        ret[#ret + 1] = { { line } }
      end
    end
  end
  local subject = table.remove(msg, 1) or ""
  if subject then
    ret[#ret + 1] = {}
    ---@diagnostic disable-next-line: missing-fields
    ret[#ret + 1] = Snacks.picker.format.commit_message({ msg = subject }, {})
  end
  if #msg > 0 then
    ret[#ret + 1] = Snacks.picker.highlight.rule()
    local virt_lines = Snacks.picker.highlight.get_virtual_lines(table.concat(msg, "\n"), { ft = "markdown" })
    for _, vl in ipairs(virt_lines) do
      ret[#ret + 1] = vl
    end
  end
  ret[#ret + 1] = Snacks.picker.highlight.rule()
  return ret
end

---@param block snacks.picker.diff.Block
---@param opts? snacks.diff.Config
function M.format_block(block, opts)
  local ret = {} ---@type snacks.picker.Highlight[][]
  vim.list_extend(ret, M.format_block_header(block, opts))
  for _, hunk in ipairs(block.hunks) do
    local hunk_lines = M.format_hunk(hunk, block, opts)
    if opts and opts.max_hunk_lines and #hunk_lines > opts.max_hunk_lines then
      hunk_lines = vim.list_slice(hunk_lines, #hunk_lines - opts.max_hunk_lines + 1)
    end
    vim.list_extend(ret, hunk_lines)
  end
  return ret
end

---@param block snacks.picker.diff.Block
---@param opts? snacks.diff.Config
function M.format_block_header(block, opts)
  local ret = {} ---@type snacks.picker.Highlight[][]
  ret[#ret + 1] = Snacks.picker.highlight.add_eol({}, "SnacksDiffHeader")

  local icon, icon_hl = Snacks.util.icon(block.file)
  local file = {} ---@type snacks.picker.Highlight[]
  file[#file + 1] = { "  " }
  file[#file + 1] = { icon, icon_hl, inline = true }
  file[#file + 1] = { "  " }

  if block.rename then
    file[#file + 1] = { block.rename.from }
    file[#file + 1] = { " -> ", "SnacksPickerDelim" }
    file[#file + 1] = { block.rename.to }
  else
    file[#file + 1] = { block.file }
  end
  Snacks.picker.highlight.insert_hl(file, "SnacksDiffHeader")
  Snacks.picker.highlight.add_eol(file, "SnacksDiffHeader")
  ret[#ret + 1] = file

  ret[#ret + 1] = Snacks.picker.highlight.add_eol({}, "SnacksDiffHeader")
  return ret
end

---@param hunk snacks.picker.diff.Hunk
---@param block snacks.picker.diff.Block
---@param opts? snacks.diff.Config
function M.format_hunk(hunk, block, opts)
  opts = opts or {}
  local a = Snacks.picker.util.align
  local ret = {} ---@type snacks.picker.Highlight[][]
  local diff = vim.deepcopy(hunk.diff)
  table.remove(diff, 1) -- remove hunk header line
  while #diff > 0 and diff[#diff]:match("^%s*$") do
    table.remove(diff) -- remove trailing empty lines
  end

  local versions = {} ---@type snacks.picker.diff.hunk.Pos[]
  versions[#versions + 1] = hunk.left
  vim.list_extend(versions, hunk.parents or {})
  versions[#versions + 1] = hunk.right
  while #versions < 2 do -- normally should not happen, but just in case
    versions[#versions + 1] = { line = hunk.line, count = 0 }
  end

  local unmerged = #versions > 2

  local code, prefixes, conflict_markers = {}, {}, {} ---@type string[], string[], table<number, string>
  for l, line in ipairs(diff) do
    prefixes[#prefixes + 1] = line:sub(1, #versions - 1)
    local code_line = line:sub(#versions)
    if unmerged and vim.tbl_contains(CONFLICT_MARKERS, code_line:match("^%s*(%S+)")) then
      conflict_markers[l] = code_line
      code_line = ""
    end
    code[#code + 1] = code_line
  end

  table.insert(code, 1, hunk.context or "") -- add hunk context for syntax highlighting
  local ft = vim.filetype.match({ filename = block.file, contents = code }) or ""
  local virt_lines = Snacks.picker.highlight.get_virtual_lines(table.concat(code, "\n"), { ft = ft })
  local context = table.remove(virt_lines, 1) -- remove hunk context virt lines
  table.remove(code, 1)

  local lines = {} ---@type table<number, string[]>
  local idx = {} ---@type number[]
  for p, pos in ipairs(versions) do
    idx[p] = idx[p] or ((pos.line or 1) - 1)
  end
  local max = 0

  for l in ipairs(diff) do
    local prefix = prefixes[l]
    local line = {} ---@type string[]
    lines[l] = line
    for i = 1, #versions do
      line[i] = ""
    end

    if not conflict_markers[l] then
      -- Increment parent versions
      for i = 1, #versions - 1 do
        local char = prefix:sub(i, i)
        if char == " " or char == "-" then
          idx[i] = idx[i] + 1
          line[i] = tostring(idx[i])
          max = math.max(max, #tostring(idx[i]))
        end
      end
    end

    -- Increment working (right)
    -- Working increments if any char is ' ' or '+' (i.e., NOT all are '-')
    local has_working = false
    for i = 1, #prefix do
      if prefix:sub(i, i) ~= "-" then
        has_working = true
        break
      end
    end
    if has_working then
      idx[#idx] = idx[#idx] + 1
      line[#idx] = tostring(idx[#idx])
      max = math.max(max, #tostring(idx[#idx]))
    end
  end

  if opts.hunk_header ~= false then
    local header = {} ---@type snacks.picker.Highlight[]
    header[#header + 1] = { "  " }
    header[#header + 1] = { " ", "Special" }
    header[#header + 1] = { " " }
    Snacks.picker.highlight.extend(header, context)
    local context_width = Snacks.picker.highlight.offset(context)
    ret[#ret + 1] = {
      { string.rep("─", context_width + 7) .. "┐", "FloatBorder" },
    }
    header[#header + 1] = { "  │", "FloatBorder" }
    ret[#ret + 1] = header
    ret[#ret + 1] = {
      { string.rep("─", context_width + 7) .. "┘", "FloatBorder" },
    }
  end

  local in_conflict = false
  for l = 1, #diff do
    local have_left, have_right = lines[l][1] ~= "", lines[l][#versions] ~= ""
    local hl = (conflict_markers[l] and "SnacksDiffConflict")
      or (have_right and not have_left and "SnacksDiffAdd")
      or (have_left and not have_right and "SnacksDiffDelete")
      or "SnacksDiffContext"

    local prefix = prefixes[l]
    if unmerged then
      local p = "  "
      local marker = conflict_markers[l] or ""
      marker = marker:match("^%s*(%S+)") or ""
      if marker == "<<<<<<<" then
        in_conflict = true
        p = "┌╴"
      elseif marker == ">>>>>>>" then
        in_conflict = false
        p = "└╴"
      elseif marker == "=======" or marker == "|||||||" then
        p = "├╴"
      elseif in_conflict then
        p = "│ "
      end
      prefix = a(p, 2) .. prefix
    end

    local line = {} ---@type snacks.picker.Highlight[]

    local line_nr = {} ---@type string[]
    for i = 1, #versions do
      line_nr[i] = a(lines[l][i], max, { align = i == #versions and "right" or "left" })
    end
    local line_col = " " .. table.concat(line_nr, "  ") .. " "
    local prefix_col = " " .. prefix .. " "

    -- empty linenr overlay that will be used for wrapped lines
    line[#line + 1] = {
      col = 0,
      virt_text = { { string.rep(" ", #line_col), hl .. "LineNr" } },
      virt_text_pos = "overlay",
      hl_mode = "replace",
      virt_text_repeat_linebreak = true,
    }

    -- linenr overlay
    line[#line + 1] = {
      col = 0,
      virt_text = { { line_col, hl .. "LineNr" } },
      virt_text_pos = "overlay",
      hl_mode = "replace",
    }

    -- empty prefix overlay that will be used for wrapped lines
    local ws = (conflict_markers[l] or code[l]):match("^(%s*)") -- add ws for breakindent
    line[#line + 1] = {
      col = #line_col,
      virt_text = { { a(prefix_col:gsub("[%-%+]", " "), #ws + #prefix_col), hl } },
      virt_text_pos = "overlay",
      hl_mode = "replace",
      virt_text_repeat_linebreak = true,
    }

    -- prefix overlay
    line[#line + 1] = {
      col = #line_col,
      virt_text = { { prefix_col, hl } },
      virt_text_pos = "overlay",
      hl_mode = "replace",
    }

    local vl = Snacks.picker.highlight.indent({}, #line_col + #prefix_col)
    if conflict_markers[l] then
      vl[#vl + 1] = { conflict_markers[l], hl }
    else
      vim.list_extend(vl, virt_lines[l] or {})
    end
    Snacks.picker.highlight.insert_hl(vl, hl)
    Snacks.picker.highlight.extend(line, vl)
    Snacks.picker.highlight.add_eol(line, hl)
    ret[#ret + 1] = line
  end
  return ret
end

return M
