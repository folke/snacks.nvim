local M = {}

---@class snacks.diff.Config
---@field max_hunk_lines? number only show last N lines of each hunk (used by GitHub PRs)
---@field hunk_header? boolean whether to show hunk header (default: true)
---@field annotations? snacks.diff.Annotation[]

---@class snacks.diff.Annotation
---@field file string
---@field side "left" | "right"
---@field left? number
---@field right? number
---@field line number
---@field text snacks.picker.Highlight[][]

---@class snacks.diff.Meta
---@field side "left" | "right"
---@field file string
---@field line number
---@field code string

---@class snacks.diff.ctx
---@field diff snacks.picker.Diff
---@field opts snacks.diff.Config
---@field block? snacks.picker.diff.Block
---@field hunk? snacks.picker.diff.Hunk
local C = {}
C.__index = C

---@param ctx snacks.diff.ctx|{}
---@return snacks.diff.ctx
function C:extend(ctx)
  return setmetatable(ctx, { __index = self })
end

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

local H = Snacks.picker.highlight
local U = Snacks.picker.util

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
  return H.render(buf, ns, ret)
end

---@param diff string|string[]|snacks.picker.Diff
---@param opts? snacks.diff.Config
function M.format(diff, opts)
  local ctx = C:extend({
    diff = M.get_diff(diff),
    opts = opts or {},
  })
  local ret = {} ---@type snacks.picker.Highlight[][]
  vim.list_extend(ret, M.format_header(ctx))
  for _, block in ipairs(ctx.diff.blocks) do
    vim.list_extend(ret, M.format_block(ctx:extend({ block = block })))
  end
  return ret
end

---@param ctx snacks.diff.ctx
function M.format_header(ctx)
  if #(ctx.diff.header or {}) == 0 then
    return {}
  end
  local popts = Snacks.picker.config.get({})
  local ret = {} ---@type snacks.picker.Highlight[][]
  local msg = {} ---@type string[]
  for _, line in ipairs(ctx.diff.header or {}) do
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
    ret[#ret + 1] = H.rule()
    local virt_lines = H.get_virtual_lines(table.concat(msg, "\n"), { ft = "markdown" })
    for _, vl in ipairs(virt_lines) do
      ret[#ret + 1] = vl
    end
  end
  ret[#ret + 1] = H.rule()
  return ret
end

---@param ctx snacks.diff.ctx
function M.format_block(ctx)
  local ret = {} ---@type snacks.picker.Highlight[][]
  vim.list_extend(ret, M.format_block_header(ctx))
  for _, hunk in ipairs(ctx.block.hunks) do
    local hunk_lines = M.format_hunk(ctx:extend({ hunk = hunk }))
    if ctx.opts and ctx.opts.max_hunk_lines and #hunk_lines > ctx.opts.max_hunk_lines then
      hunk_lines = vim.list_slice(hunk_lines, #hunk_lines - ctx.opts.max_hunk_lines + 1)
    end
    vim.list_extend(ret, hunk_lines)
  end
  return ret
end

---@param ctx snacks.diff.ctx
function M.format_block_header(ctx)
  local block = assert(ctx.block)
  local ret = {} ---@type snacks.picker.Highlight[][]
  ret[#ret + 1] = H.add_eol({}, "SnacksDiffHeader")

  local icon, icon_hl = Snacks.util.icon(block.file)
  local file = {} ---@type snacks.picker.Highlight[]
  file[#file + 1] = { "  " }
  -- needed to play nice with markview / markdown-renderer
  file[#file + 1] = { col = 0, virt_text = { { "  ", "SnacksDiffHeader" } }, virt_text_pos = "overlay" }
  file[#file + 1] = { icon, icon_hl, inline = true }
  file[#file + 1] = { "  " }

  if block.rename then
    file[#file + 1] = { block.rename.from }
    file[#file + 1] = { " -> ", "SnacksPickerDelim" }
    file[#file + 1] = { block.rename.to }
  else
    file[#file + 1] = { block.file }
  end
  H.insert_hl(file, "SnacksDiffHeader")
  H.add_eol(file, "SnacksDiffHeader")
  ret[#ret + 1] = file

  ret[#ret + 1] = H.add_eol({}, "SnacksDiffHeader")
  return ret
end

---@param ctx snacks.diff.ctx
function M.parse_hunk(ctx)
  local block = assert(ctx.block)
  local hunk = assert(ctx.hunk)
  local diff = vim.deepcopy(hunk.diff)
  local versions = {} ---@type snacks.picker.diff.hunk.Pos[]
  local unmerged = #versions > 2
  local lines, prefixes, conflict_markers = {}, {}, {} ---@type string[], string[], table<number, string>

  -- build versions
  versions[#versions + 1] = hunk.left
  vim.list_extend(versions, hunk.parents or {})
  versions[#versions + 1] = hunk.right
  while #versions < 2 do -- normally should not happen, but just in case
    versions[#versions + 1] = { line = hunk.line, count = 0 }
  end

  -- setup diff lines
  table.remove(diff, 1) -- remove hunk header line
  while #diff > 0 and diff[#diff]:match("^%s*$") do
    table.remove(diff) -- remove trailing empty lines
  end

  -- parse diff lines
  for l, line in ipairs(diff) do
    prefixes[#prefixes + 1] = line:sub(1, #versions - 1)
    local code_line = line:sub(#versions)
    if unmerged and vim.tbl_contains(CONFLICT_MARKERS, code_line:match("^%s*(%S+)")) then
      conflict_markers[l] = code_line
      code_line = ""
    end
    lines[#lines + 1] = code_line
  end

  -- generate virt lines
  table.insert(lines, 1, hunk.context or "") -- add hunk context for syntax highlighting
  local ft = vim.filetype.match({ filename = block.file, contents = lines }) or ""
  local text = H.get_virtual_lines(table.concat(lines, "\n"), { ft = ft })
  local context = table.remove(text, 1) -- remove hunk context virt lines
  table.remove(lines, 1) -- remove hunk context code line

  ---@class snacks.diff.hunk.Parse
  local ret = {
    len = #diff, -- number of lines in hunk
    versions = versions, -- positions of each version
    lines = lines, -- code lines of hunk
    text = text, -- virt lines of hunk
    prefixes = prefixes, -- diff prefixes of hunk
    conflict_markers = conflict_markers, -- conflict markers lines of hunk
    context = context, -- virt lines of hunk context
    unmerged = unmerged, -- whether hunk is unmerged
  }
  return ret
end

--- Build hunk line index for each version
---@param parse snacks.diff.hunk.Parse
function M.build_hunk_index(parse)
  local versions = parse.versions
  local index = {} ---@type table<number, number>[]|{max: number}
  local idx = {} ---@type number[]
  for p, pos in ipairs(versions) do
    idx[p] = idx[p] or ((pos.line or 1) - 1)
  end
  local max = 0
  for l = 1, parse.len do
    local prefix = parse.prefixes[l]
    index[l] = {}

    if not parse.conflict_markers[l] then
      -- Increment parent versions
      for i = 1, #versions - 1 do
        local char = prefix:sub(i, i)
        if char == " " or char == "-" then
          idx[i] = idx[i] + 1
          index[l][i] = idx[i]
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
      index[l][#idx] = idx[#idx]
      max = math.max(max, #tostring(idx[#idx]))
    end
  end
  index.max = max
  return index
end

---@param parse snacks.diff.hunk.Parse
function M.format_hunk_header(parse)
  local ret = {} ---@type snacks.picker.Highlight[][]
  local header = {} ---@type snacks.picker.Highlight[]
  header[#header + 1] = { "  " }
  header[#header + 1] = { " ", "Special" }
  header[#header + 1] = { " " }
  H.extend(header, parse.context)
  local context_width = H.offset(parse.context)
  ret[#ret + 1] = {
    { string.rep("─", context_width + 7) .. "┐", "FloatBorder" },
  }
  header[#header + 1] = { "  │", "FloatBorder" }
  ret[#ret + 1] = header
  ret[#ret + 1] = {
    { string.rep("─", context_width + 7) .. "┘", "FloatBorder" },
  }
  return ret
end

---@param ctx snacks.diff.ctx
function M.format_hunk(ctx)
  local block = assert(ctx.block)
  local ret = {} ---@type snacks.picker.Highlight[][]

  local parse = M.parse_hunk(ctx)

  local annotations = {} ---@type table<string, snacks.picker.Highlight[][]>
  for _, annotation in ipairs(ctx.opts.annotations or {}) do
    if annotation.file == block.file then
      annotations[("%s:%d"):format(annotation.side, annotation.line)] = annotation.text
    end
  end

  local index = M.build_hunk_index(parse)

  if ctx.opts.hunk_header ~= false then
    vim.list_extend(ret, M.format_hunk_header(parse))
  end

  local in_conflict = false
  for l = 1, parse.len do
    local have_left, have_right = index[l][1] ~= nil, index[l][#parse.versions] ~= nil
    local hl = (parse.conflict_markers[l] and "SnacksDiffConflict")
      or (have_right and not have_left and "SnacksDiffAdd")
      or (have_left and not have_right and "SnacksDiffDelete")
      or "SnacksDiffContext"

    local prefix = parse.prefixes[l]
    if parse.unmerged then
      local p = "  "
      local marker = parse.conflict_markers[l] or ""
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
      prefix = U.align(p, 2) .. prefix
    end

    local line = {} ---@type snacks.picker.Highlight[]

    local line_nr = {} ---@type string[]
    for i = 1, #parse.versions do
      line_nr[i] =
        U.align(tostring(index[l][i] or ""), index.max, { align = i == #parse.versions and "right" or "left" })
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
    local ws = (parse.conflict_markers[l] or parse.lines[l]):match("^(%s*)") -- add ws for breakindent
    line[#line + 1] = {
      col = #line_col,
      virt_text = { { U.align(prefix_col:gsub("[%-%+]", " "), #ws + #prefix_col), hl } },
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

    if have_left or have_right then
      line[#line + 1] = {
        "",
        meta = {
          ---@type snacks.diff.Meta
          diff = {
            side = have_right and "right" or "left",
            file = block.file,
            line = have_right and index[l][#parse.versions] or index[l][1],
            code = parse.lines[l],
          },
        },
      }
    end

    ret[#ret + 1] = line

    local annot_left = "left:" .. (index[l][1] or "")
    local annot_right = "right:" .. (index[l][#parse.versions] or "")
    local ann = annotations[annot_left] or annotations[annot_right]
    if ann then
      vim.list_extend(
        ret,
        M.format_annotation(ann, {
          indent = { line[1] },
          indent_width = #line_col,
          hl = hl,
        })
      )
    end

    local vl = H.indent({}, #line_col + #prefix_col)
    if parse.conflict_markers[l] then
      vl[#vl + 1] = { parse.conflict_markers[l], hl }
    else
      vim.list_extend(vl, parse.text[l] or {})
    end
    H.insert_hl(vl, hl)
    H.extend(line, vl)
    H.add_eol(line, hl)
  end
  return ret
end

---@param annotation snacks.picker.Highlight[][]
---@param ctx {indent: snacks.picker.Highlight[][], indent_width: number, hl: string}
function M.format_annotation(annotation, ctx)
  local ret = {} ---@type snacks.picker.Highlight[][]
  local box, width = M.format_box(annotation)

  local empty = vim.deepcopy(ctx.indent) ---@type snacks.picker.Highlight[]
  vim.list_extend(empty, H.indent({}, ctx.indent_width + 2, ctx.hl))
  H.add_eol(empty, ctx.hl)

  ret[#ret + 1] = vim.deepcopy(empty)
  for _, line in ipairs(box) do
    for _, chunk in ipairs(line) do
      if chunk.virt_text_win_col then
        chunk.virt_text_win_col = chunk.virt_text_win_col + ctx.indent_width + 2
      end
    end
    local al = vim.deepcopy(ctx.indent)
    local vl = H.indent({}, ctx.indent_width + 2, ctx.hl)
    vl[#vl + 1] = { -- repeat indent for the space before box
      col = ctx.indent_width,
      virt_text = { { "  ", ctx.hl } },
      virt_text_pos = "overlay",
      hl_mode = "replace",
      virt_text_repeat_linebreak = true,
    }
    H.extend(al, vl)
    H.extend(al, vim.deepcopy(line))
    H.add_eol(al, ctx.hl, width + ctx.indent_width + 6)
    ret[#ret + 1] = al
  end
  ret[#ret + 1] = vim.deepcopy(empty)
  return ret
end

---@param lines snacks.picker.Highlight[][]
---@param border_hl? string
function M.format_box(lines, border_hl)
  border_hl = border_hl or "FloatBorder"
  local ret = {} ---@type snacks.picker.Highlight[][]
  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, H.offset(line, { char_idx = true }))
  end
  width = math.max(width, 50) --[[@as number]]

  ---@param text snacks.picker.Highlight[]
  ---@param col? number
  local function vt(text, col)
    ---@type snacks.picker.Highlight
    return {
      col = 0,
      virt_text_pos = "overlay",
      virt_text_win_col = col,
      virt_text = text,
      virt_text_repeat_linebreak = true,
    }
  end

  ret[#ret + 1] = {
    vt({
      { "┌", border_hl },
      { string.rep("─", width + 2), border_hl },
      { "┐", border_hl },
    }),
  }
  for _, line in ipairs(lines) do
    ret[#ret + 1] = {
      vt({
        { "│", border_hl },
        { " " },
      }),
      { "  " },
    }
    H.extend(ret[#ret], vim.deepcopy(line))
    table.insert(ret[#ret], vt({ { "│", border_hl } }, width + 3))
  end
  ret[#ret + 1] = {
    vt({
      { "└", border_hl },
      { string.rep("─", width + 2), border_hl },
      { "┘", border_hl },
    }),
  }
  return ret, width
end

return M
