---@class snacks.picker.highlight
local M = {}

M.langs = {} ---@type table<string, boolean>
M._scratch = {} ---@type table<string, number>

---@param source string
---@param lang string
function M.scratch_buf(source, lang)
  local buf = M._scratch[lang]
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, "snacks://picker/highlight/" .. lang)
    M._scratch[lang] = buf
  end
  vim.bo[buf].fixeol = false
  vim.bo[buf].eol = false
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(source, "\n", { plain = true }))
  return buf
end

---@param opts? {buf?:number, code?:string, ft?:string, lang?:string, file?:string, extmarks?:boolean}
function M.get_highlights(opts)
  opts = opts or {}
  assert(opts.buf or opts.code, "buf or code is required")
  assert(not (opts.buf and opts.code), "only one of buf or code is allowed")

  local ret = {} ---@type table<number, snacks.picker.Extmark[]>

  local ft = opts.ft
    or (opts.buf and vim.bo[opts.buf].filetype)
    or (opts.file and vim.filetype.match({ filename = opts.file, buf = 0 }))
    or vim.bo.filetype
  local lang = Snacks.util.get_lang(opts.lang or ft)
  lang = lang and lang:lower() or nil
  local parser, buf ---@type vim.treesitter.LanguageTree?, number?

  if lang then
    local ok = false
    buf = opts.buf or M.scratch_buf(opts.code, lang)
    ok, parser = pcall(vim.treesitter.get_parser, buf, lang)
    parser = ok and parser or nil
  end

  if parser and buf then
    parser:parse(true)
    parser:for_each_tree(function(tstree, tree)
      if not tstree then
        return
      end
      local query = vim.treesitter.query.get(tree:lang(), "highlights")
      -- Some injected languages may not have highlight queries.
      if not query then
        return
      end

      for capture, node, metadata in query:iter_captures(tstree:root(), buf) do
        ---@type string
        local name = query.captures[capture]
        if name ~= "spell" then
          local range = { node:range() } ---@type number[]
          local multi = range[1] ~= range[3]
          local text = multi
              and vim.split(vim.treesitter.get_node_text(node, buf, metadata[capture]), "\n", { plain = true })
            or {}
          for row = range[1] + 1, range[3] + 1 do
            local first, last = row == range[1] + 1, row == range[3] + 1
            local end_col = last and range[4] or #(text[row - range[1]] or "")
            end_col = multi and first and end_col + range[2] or end_col
            ret[row] = ret[row] or {}
            table.insert(ret[row], {
              col = first and range[2] or 0,
              end_col = end_col,
              priority = (tonumber(metadata.priority or metadata[capture] and metadata[capture].priority) or 100),
              conceal = metadata.conceal or metadata[capture] and metadata[capture].conceal,
              hl_group = "@" .. name .. "." .. lang,
            })
          end
        end
      end
    end)
  end

  --- Add buffer extmarks
  if opts.buf and opts.extmarks then
    local extmarks = vim.api.nvim_buf_get_extmarks(opts.buf, -1, 0, -1, { details = true })
    for _, extmark in pairs(extmarks) do
      local row = extmark[2] + 1
      ret[row] = ret[row] or {}
      local e = extmark[4]
      if e then
        e.sign_name = nil
        e.sign_text = nil
        e.ns_id = nil
        e.end_row = nil
        e.col = extmark[3]
        if e.virt_text_pos and not vim.tbl_contains({ "eol", "overlay", "right_align", "inline" }, e.virt_text_pos) then
          e.virt_text = nil
          e.virt_text_pos = nil
        end
        table.insert(ret[row], e)
      end
    end
  end

  return ret
end

---@param source string|number
---@param opts? {ft:string, bg?: string}
---@return snacks.picker.Text[]
function M.get_virtual_lines(source, opts)
  opts = opts or {}

  local lines = type(source) == "number" and vim.api.nvim_buf_get_lines(source, 0, -1, false)
    or vim.split(source --[[@as string]], "\n")

  local extmarks = M.get_highlights({
    buf = type(source) == "number" and source or nil,
    code = type(source) == "string" and source or nil,
    ft = opts.ft,
    lang = nil,
  })
  if not extmarks then
    return vim.tbl_map(function(line)
      return { { line } }
    end, lines)
  end

  local index = {} ---@type table<number, table<number, string>>
  for row, exts in pairs(extmarks) do
    for _, e in ipairs(exts) do
      if e.hl_group and e.end_col then
        index[row] = index[row] or {}
        for i = e.col + 1, e.end_col do
          index[row][i] = e.hl_group
        end
      end
    end
  end

  local ret = {} ---@type snacks.picker.Text[]
  for i = 1, #lines do
    local line = lines[i]
    local from = 0
    local hl_group = nil ---@type string?

    ---@param to number
    local function add(to)
      if to >= from then
        ret[i] = ret[i] or {}
        local text = line:sub(from, to)
        local hl = opts.bg and { hl_group or "Normal", opts.bg } or hl_group
        if #text > 0 then
          table.insert(ret[i], { text, hl })
        end
      end
      from = to + 1
      hl_group = nil
    end

    for col = 1, #line do
      local hl = index[i] and index[i][col]
      if hl ~= hl_group then
        add(col - 1)
        hl_group = hl
      end
    end
    add(#line)
  end
  return ret
end

---@param line snacks.picker.Highlight[]
---@param opts? {char_idx?:boolean}
function M.offset(line, opts)
  opts = opts or {}
  local offset = 0
  for _, t in ipairs(line) do
    if type(t[1]) == "string" then
      if t.virtual then
        offset = offset + vim.api.nvim_strwidth(t[1])
      elseif opts.char_idx then
        offset = offset + vim.api.nvim_strwidth(t[1])
      else
        offset = offset + #t[1]
      end
    elseif t.virt_text_pos == "inline" and t.virt_text then
      offset = offset + M.offset(t.virt_text) + (t.col or 0)
    end
  end
  return offset
end

---@param line snacks.picker.Highlight[]
---@param positions number[]
---@param offset? number
function M.matches(line, positions, offset)
  offset = offset or 0
  for _, pos in ipairs(positions) do
    table.insert(line, {
      col = pos - 1 + offset,
      end_col = pos + offset,
      hl_group = "SnacksPickerMatch",
    })
  end
  return line
end

---@param line snacks.picker.Highlight[]
---@param item snacks.picker.Item
---@param text string
---@param opts? {hl_group?:string, lang?:string}
function M.format(item, text, line, opts)
  opts = opts or {}
  local offset = M.offset(line)
  item._ = item._ or {}
  item._.ts = item._.ts or {}
  local highlights = item._.ts[text] ---@type table<number, snacks.picker.Extmark[]>?
  if not highlights then
    highlights = M.get_highlights({ code = text, ft = item.ft, lang = opts.lang or item.lang, file = item.file })[1]
      or {}
    item._.ts[text] = highlights
  end
  highlights = vim.deepcopy(highlights)
  for _, extmark in ipairs(highlights) do
    extmark.col = extmark.col + offset
    extmark.end_col = extmark.end_col + offset
    line[#line + 1] = extmark
  end
  line[#line + 1] = { text, opts.hl_group }
end

---@param line snacks.picker.Highlight[]
---@param patterns table<string,string>
function M.highlight(line, patterns)
  local offset = M.offset(line)
  local text ---@type string?
  for i = #line, 1, -1 do
    if type(line[i][1]) == "string" then
      text = line[i][1]
      break
    end
  end
  if not text then
    return
  end
  offset = offset - #text
  for pattern, hl in pairs(patterns) do
    local from, to, match = text:find(pattern)
    while from do
      if match then
        from, to = text:find(match, from, true)
      end
      table.insert(line, {
        col = offset + from - 1,
        end_col = offset + to,
        hl_group = hl,
      })
      from, to = text:find(pattern, to + 1)
    end
  end
end

---@param line snacks.picker.Highlight[]
function M.markdown(line)
  M.highlight(line, {
    ["^# .*"] = "@markup.heading.1.markdown",
    ["^## .*"] = "@markup.heading.2.markdown",
    ["^### .*"] = "@markup.heading.3.markdown",
    ["^#### .*"] = "@markup.heading.4.markdown",
    ["^##### .*"] = "@markup.heading.5.markdown",
    ["`.-`"] = "SnacksPickerCode",
    ["^%s*[%-%*]"] = "@markup.list.markdown",
    ["%*.-%*"] = "SnacksPickerItalic",
    ["%*%*.-%*%*"] = "SnacksPickerBold",
  })
end

---@param prefix string
---@param links? table<string, string>
function M.winhl(prefix, links)
  links = links or {}
  local winhl = {
    NormalFloat = "",
    FloatBorder = "Border",
    FloatTitle = "Title",
    FloatFooter = "Footer",
    CursorLine = "CursorLine",
  }
  local ret = {} ---@type string[]
  local groups = {} ---@type table<string, string>
  for k, v in pairs(winhl) do
    groups[v] = links[k] or (prefix == "SnacksPicker" and k or ("SnacksPicker" .. v))
    ret[#ret + 1] = ("%s:%s%s"):format(k, prefix, v)
  end
  Snacks.util.set_hl(groups, { prefix = prefix, default = true })
  return table.concat(ret, ",")
end

--- Resolves the first flex text in the line.
---@param line snacks.picker.Highlight[]
---@param max_width number
function M.resolve(line, max_width)
  local offset = 0
  local width = 0
  local resolve ---@type number?

  while true do
    for t, text in ipairs(line) do
      local w = M.offset({ text }, { char_idx = true })
      if not resolve and type(text) == "table" and text.resolve then
        ---@cast text snacks.picker.Text
        resolve = t
      elseif resolve then
        width = width + w
      else
        width = width + w
        offset = offset + w
      end
    end

    if resolve then
      local ret = {} ---@type snacks.picker.Highlight[]
      vim.list_extend(ret, line, 1, resolve - 1)
      offset = M.offset(ret)
      vim.list_extend(ret, line[resolve].resolve(max_width - width))
      local diff = M.offset(ret) - offset
      vim.list_extend(ret, line, resolve + 1)
      M.fix_offset(ret, diff, resolve + 1)
      line = ret
      ret = {}
      resolve = nil
    else
      return line
    end
  end
end

---@param line snacks.picker.Highlight[]
---@param opts? {offset?:number}
function M.to_text(line, opts)
  local offset = opts and opts.offset or 0
  local ret = {} ---@type snacks.picker.Extmark[]
  local col = offset
  local parts = {} ---@type string[]
  for _, text in ipairs(line) do
    if (type(text[2]) == "string" and text[1] == nil) or vim.tbl_isempty(text) then
      text[1] = ""
    end
    if type(text[1]) == "string" then
      ---@cast text snacks.picker.Text
      if text.virtual then
        table.insert(ret, {
          col = col,
          virt_text = { { text[1], text[2] } },
          virt_text_pos = "overlay",
          hl_mode = "combine",
        })
        parts[#parts + 1] = string.rep(" ", vim.api.nvim_strwidth(text[1]))
      else
        table.insert(ret, {
          col = col,
          end_col = col + #text[1],
          hl_group = text[2],
          field = text.field,
        })
        parts[#parts + 1] = text[1]
      end
      col = col + #parts[#parts]
    else
      text = vim.deepcopy(text)
      ---@cast text snacks.picker.Extmark
      -- fix extmark col and end_col
      text.col = text.col + offset
      if text.end_col then
        text.end_col = text.end_col + offset
      end
      table.insert(ret, text)
    end
  end
  return table.concat(parts), ret
end

---@param hl snacks.picker.Highlight[]
---@param start_idx? number
function M.fix_offset(hl, offset, start_idx)
  for i, t in ipairs(hl) do
    if start_idx == nil or i >= start_idx then
      if t.col then
        t.col = t.col + offset
      end
      if t.end_col then
        t.end_col = t.end_col + offset
      end
    end
  end
  return hl
end

---@param dst snacks.picker.Highlight[]
---@param src snacks.picker.Highlight[]
function M.extend(dst, src)
  local offset = M.offset(dst)
  M.fix_offset(src, offset)
  return vim.list_extend(dst, src)
end

---@param buf number
---@param ns number
---@param lines snacks.picker.Highlight[][]
---@param opts? {append?:boolean}
function M.render(buf, ns, lines, opts)
  opts = opts or {}
  local old_lines = opts.append and {} or vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  vim.bo[buf].modifiable = true
  if not opts.append then
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  end

  local changed = #lines ~= #old_lines
  local offset = opts.append and vim.api.nvim_buf_line_count(buf) or 0
  offset = offset == 1 and (vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""):find("^%s*$") and 0 or offset
  for l, line in ipairs(lines) do
    local line_text, extmarks = Snacks.picker.highlight.to_text(line)
    if line_text ~= old_lines[l] then
      vim.api.nvim_buf_set_lines(buf, offset + l - 1, offset + l, false, { line_text })
      changed = true
    end
    for _, extmark in ipairs(extmarks) do
      local e = vim.deepcopy(extmark)
      e.col, e.row, e.field = nil, nil, nil
      local ok, err = pcall(vim.api.nvim_buf_set_extmark, buf, ns, offset + l - 1, extmark.col, e)
      if not ok then
        Snacks.notify.error(
          "Failed to set extmark. This should not happen. Please report.\n"
            .. err
            .. "\n```lua\n"
            .. vim.inspect(extmark)
            .. "\n```"
        )
      end
    end
  end

  if not opts.append and #lines < #old_lines then
    vim.api.nvim_buf_set_lines(buf, #lines, -1, false, {})
  end

  vim.bo[buf].modified = false
  vim.bo[buf].modifiable = false
  return changed
end

---@alias snacks.picker.badge.color string|{ fg:string, bg:string }
local badge_cache = {} ---@type table<string, {hl:string, color:snacks.picker.badge.color}>

---@param color snacks.picker.badge.color
local function badge_hl(color)
  local key = type(color) == "string" and color or ("%s:%s"):format(color.fg or "", color.bg or "")
  if badge_cache[key] then
    return badge_cache[key].hl
  end

  local fg, bg ---@type string, string
  if type(color) == "string" then
    if color:sub(1, 1) == "#" then
      bg = color
    else
      fg, bg = Snacks.util.color(color, "fg"), Snacks.util.color(color, "bg")
    end
  else
    fg, bg = color.fg, color.bg
  end

  if not fg and not bg then -- default to inverse of Normal
    fg = Snacks.util.color("Normal", "bg") or "#ffffff"
    bg = Snacks.util.color("Normal", "fg") or "#000000"
  elseif fg and not bg then -- set bg to a blended version of fg and Normal bg
    bg = bg or Snacks.util.color("Normal", "bg") or "#000000"
    bg = Snacks.util.blend(fg, bg, 0.1)
  elseif bg and not fg then -- calculate fg based on bg brightness
    local light, dark = "#ffffff", "#000000"
    do
      local normal_fg = Snacks.util.color("Normal", "fg")
      local normal_bg = Snacks.util.color("Normal", "bg")
      if vim.o.background == "light" then
        normal_fg, normal_bg = normal_bg, normal_fg
      end
      light = normal_fg or light
      dark = normal_bg or dark
    end
    local r, g, b = bg:match("#?(%x%x)(%x%x)(%x%x)")
    r, g, b = tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
    local yiq = (r * 299 + g * 587 + b * 114) / 1000
    fg = yiq >= 128 and dark or light
  end

  local hl_group = ("SnacksBadge_%s_%s"):format(fg:sub(2), bg:sub(2))
  vim.api.nvim_set_hl(0, hl_group, { fg = fg, bg = bg })
  vim.api.nvim_set_hl(0, hl_group .. "Inv", { fg = bg })
  badge_cache[key] = { hl = hl_group, color = color }
  return hl_group
end

--- Renders a badge
---@param text string
---@param color snacks.picker.badge.color
function M.badge(text, color)
  local left_sep, right_sep = "", ""

  local hl_group = badge_hl(color)
  ---@type snacks.picker.Highlight[]
  return {
    { left_sep, hl_group .. "Inv", virtual = true },
    { text, hl_group },
    { right_sep, hl_group .. "Inv", virtual = true },
  }
end

vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("snacks.picker.highlight,badges", { clear = true }),
  callback = function(ev)
    local badges = badge_cache
    badge_cache = {}
    for _, v in pairs(badges) do
      badge_hl(v.color)
    end
  end,
})

return M
