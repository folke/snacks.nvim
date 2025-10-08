---@class snacks.picker.formatters
---@field [string] snacks.picker.format
local M = {}

local uv = vim.uv or vim.loop

function M.severity(item, picker)
  local ret = {} ---@type snacks.picker.Highlight[]
  local severity = item.severity
  severity = type(severity) == "number" and vim.diagnostic.severity[severity] or severity
  if not severity or type(severity) == "number" then
    return ret
  end
  ---@cast severity string
  local lower = severity:lower()
  local cap = severity:sub(1, 1):upper() .. lower:sub(2)

  if picker.opts.formatters.severity.pos == "right" then
    return {
      {
        col = 0,
        virt_text = { { picker.opts.icons.diagnostics[cap], "Diagnostic" .. cap } },
        virt_text_pos = "right_align",
        hl_mode = "combine",
      },
    }
  end

  if picker.opts.formatters.severity.icons then
    ret[#ret + 1] = { picker.opts.icons.diagnostics[cap], "Diagnostic" .. cap, virtual = true }
    ret[#ret + 1] = { " ", virtual = true }
  end

  if picker.opts.formatters.severity.level then
    ret[#ret + 1] = { lower:upper(), "Diagnostic" .. cap, virtual = true }
    ret[#ret + 1] = { " ", virtual = true }
  end

  return ret
end

---@param item snacks.picker.Item
function M.filename(item, picker)
  ---@type snacks.picker.Highlight[]
  local ret = {}
  if not item.file then
    return ret
  end
  local path = Snacks.picker.util.path(item) or item.file
  path = Snacks.picker.util.truncpath(path, picker.opts.formatters.file.truncate or 40, { cwd = picker:cwd() })
  local name, cat = path, "file"
  if item.buf and vim.api.nvim_buf_is_loaded(item.buf) then
    name = vim.bo[item.buf].filetype
    cat = "filetype"
  elseif item.dir then
    cat = "directory"
  end

  if picker.opts.icons.files.enabled ~= false then
    local icon, hl = Snacks.util.icon(name, cat, {
      fallback = picker.opts.icons.files,
    })
    if item.dir and item.open then
      icon = picker.opts.icons.files.dir_open
    end
    icon = Snacks.picker.util.align(icon, picker.opts.formatters.file.icon_width or 2)
    ret[#ret + 1] = { icon, hl, virtual = true }
  end

  local base_hl = item.dir and "SnacksPickerDirectory" or "SnacksPickerFile"
  local function is(prop)
    local it = item
    while it do
      if it[prop] then
        return true
      end
      it = it.parent
    end
  end

  if is("ignored") then
    base_hl = "SnacksPickerPathIgnored"
  elseif is("hidden") then
    base_hl = "SnacksPickerPathHidden"
  elseif item.filename_hl then
    base_hl = item.filename_hl
  end
  local dir_hl = "SnacksPickerDir"

  if picker.opts.formatters.file.filename_only then
    path = vim.fn.fnamemodify(item.file, ":t")
    ret[#ret + 1] = { path, base_hl, field = "file" }
  else
    local dir, base = path:match("^(.*)/(.+)$")
    if base and dir then
      if picker.opts.formatters.file.filename_first then
        ret[#ret + 1] = { base, base_hl, field = "file" }
        ret[#ret + 1] = { " " }
        ret[#ret + 1] = { dir, dir_hl, field = "file" }
      else
        ret[#ret + 1] = { dir .. "/", dir_hl, field = "file" }
        ret[#ret + 1] = { base, base_hl, field = "file" }
      end
    else
      ret[#ret + 1] = { path, base_hl, field = "file" }
    end
  end
  if item.pos and item.pos[1] > 0 then
    ret[#ret + 1] = { ":", "SnacksPickerDelim" }
    ret[#ret + 1] = { tostring(item.pos[1]), "SnacksPickerRow" }
    if item.pos[2] > 0 then
      ret[#ret + 1] = { ":", "SnacksPickerDelim" }
      ret[#ret + 1] = { tostring(item.pos[2]), "SnacksPickerCol" }
    end
  end
  ret[#ret + 1] = { " " }
  if item.type == "link" then
    local real = uv.fs_realpath(item.file)
    local broken = not real
    real = real or uv.fs_readlink(item.file)
    if real then
      ret[#ret + 1] = { "-> ", "SnacksPickerDelim" }
      ret[#ret + 1] =
        { Snacks.picker.util.truncpath(real, 20), broken and "SnacksPickerLinkBroken" or "SnacksPickerLink" }
      ret[#ret + 1] = { " " }
    end
  end
  return ret
end

function M.file(item, picker)
  ---@type snacks.picker.Highlight[]
  local ret = {}

  if item.label then
    ret[#ret + 1] = { item.label, "SnacksPickerLabel" }
    ret[#ret + 1] = { " ", virtual = true }
  end

  if item.parent then
    vim.list_extend(ret, M.tree(item, picker))
  end

  if item.status then
    vim.list_extend(ret, M.file_git_status(item, picker))
  end

  if item.severity then
    vim.list_extend(ret, M.severity(item, picker))
  end

  vim.list_extend(ret, M.filename(item, picker))

  if item.comment then
    table.insert(ret, { item.comment, "SnacksPickerComment" })
    table.insert(ret, { " " })
  end

  if item.line then
    Snacks.picker.highlight.format(item, item.line, ret)
    table.insert(ret, { " " })
  end
  return ret
end

function M.git_log(item, picker)
  local a = Snacks.picker.util.align
  local ret = {} ---@type snacks.picker.Highlight[]
  ret[#ret + 1] = { picker.opts.icons.git.commit, "SnacksPickerGitCommit" }
  local c = item.commit or item.branch or "HEAD"
  ret[#ret + 1] = { a(c, 8, { truncate = true }), "SnacksPickerGitCommit" }

  ret[#ret + 1] = { " " }
  if item.date then
    ret[#ret + 1] = { a(item.date, 16), "SnacksPickerGitDate" }
  end
  ret[#ret + 1] = { " " }

  local msg = item.msg ---@type string
  local type, scope, breaking, body = msg:match("^(%S+)%s*(%(.-%))(!?):%s*(.*)$")
  if not type then
    type, breaking, body = msg:match("^(%S+)(!?):%s*(.*)$")
  end
  local msg_hl = "SnacksPickerGitMsg"
  if type and body then
    local dimmed = vim.tbl_contains({ "chore", "bot", "build", "ci", "style", "test" }, type)
    msg_hl = dimmed and "SnacksPickerDimmed" or "SnacksPickerGitMsg"
    ret[#ret + 1] =
      { type, breaking ~= "" and "SnacksPickerGitBreaking" or dimmed and "SnacksPickerBold" or "SnacksPickerGitType" }
    if scope and scope ~= "" then
      ret[#ret + 1] = { scope, "SnacksPickerGitScope" }
    end
    if breaking ~= "" then
      ret[#ret + 1] = { "!", "SnacksPickerGitBreaking" }
    end
    ret[#ret + 1] = { ":", "SnacksPickerDelim" }
    ret[#ret + 1] = { " " }
    msg = body
  end
  ret[#ret + 1] = { msg, msg_hl }
  Snacks.picker.highlight.markdown(ret)
  Snacks.picker.highlight.highlight(ret, {
    ["#%d+"] = "SnacksPickerGitIssue",
  })
  return ret
end

function M.git_branch(item, picker)
  local a = Snacks.picker.util.align
  local ret = {} ---@type snacks.picker.Highlight[]
  if item.current then
    ret[#ret + 1] = { a("", 2), "SnacksPickerGitBranchCurrent" }
  else
    ret[#ret + 1] = { a("", 2) }
  end
  if item.detached then
    ret[#ret + 1] = { a("(detached HEAD)", 30, { truncate = true }), "SnacksPickerGitDetached" }
  else
    ret[#ret + 1] = { a(item.branch, 30, { truncate = true }), "SnacksPickerGitBranch" }
  end
  ret[#ret + 1] = { " " }
  local offset = Snacks.picker.highlight.offset(ret)
  local log = M.git_log(item, picker)
  Snacks.picker.highlight.fix_offset(log, offset)
  vim.list_extend(ret, log)
  return ret
end

function M.git_stash(item, picker)
  local a = Snacks.picker.util.align
  local ret = {} ---@type snacks.picker.Highlight[]
  ret[#ret + 1] = { a(item.stash, 10), "SnacksPickerIdx" }
  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { a(item.branch, 10, { truncate = true }), "SnacksPickerGitBranch" }
  ret[#ret + 1] = { " " }
  local offset = Snacks.picker.highlight.offset(ret)
  local log = M.git_log(item, picker)
  Snacks.picker.highlight.fix_offset(log, offset)
  vim.list_extend(ret, log)
  return ret
end

function M.tree(item, picker)
  local ret = {} ---@type snacks.picker.Highlight[]
  local icons = picker.opts.icons.tree
  local indent = {} ---@type string[]
  local node = item
  while node and node.parent do
    local is_last, icon = node.last, ""
    if node ~= item then
      icon = is_last and "  " or icons.vertical
    else
      icon = is_last and icons.last or icons.middle
    end
    table.insert(indent, 1, icon)
    node = node.parent
  end
  ret[#ret + 1] = { table.concat(indent), "SnacksPickerTree" }
  return ret
end

function M.undo(item, picker)
  local ret = {} ---@type snacks.picker.Highlight[]
  local entry = item.item ---@type vim.fn.undotree.entry
  local a = Snacks.picker.util.align
  if item.current then
    ret[#ret + 1] = { a("", 2), "SnacksPickerUndoCurrent" }
  else
    ret[#ret + 1] = { a("", 2) }
  end
  vim.list_extend(ret, M.tree(item, picker))
  local w = vim.api.nvim_strwidth(ret[#ret][1])

  ret[#ret + 1] = { tostring(entry.seq), "SnacksPickerIdx" }
  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { a(" ", 8 - w - #tostring(entry.seq)) }
  ret[#ret + 1] = { a(Snacks.picker.util.reltime(entry.time), 15), "SnacksPickerTime" }
  ret[#ret + 1] = { " " }
  local function num(v, prefix)
    v = v or 0
    return a((v and v > 0 and prefix .. v or ""), 4)
  end
  ret[#ret + 1] = { num(item.added, "+"), "SnacksPickerUndoAdded" }
  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { num(item.removed, "-"), "SnacksPickerUndoRemoved" }
  if entry.save then
    ret[#ret + 1] = { " " }
    ret[#ret + 1] = { a(picker.opts.icons.undo.saved, 2), "SnacksPickerUndoSaved" }
  end
  return ret
end

function M.lsp_symbol(item, picker)
  local opts = picker.opts --[[@as snacks.picker.lsp.symbols.Config]]
  local ret = {} ---@type snacks.picker.Highlight[]
  if item.tree and not opts.workspace then
    vim.list_extend(ret, M.tree(item, picker))
  end
  local kind = item.kind or "Unknown" ---@type string
  local kind_hl = "SnacksPickerIcon" .. kind
  ret[#ret + 1] = { picker.opts.icons.kinds[kind], kind_hl }
  ret[#ret + 1] = { " " }
  local name = vim.trim(item.name:gsub("\r?\n", " "))
  name = name == "" and item.detail or name
  Snacks.picker.highlight.format(item, name, ret)

  if opts.workspace then
    local offset = Snacks.picker.highlight.offset(ret, { char_idx = true })
    ret[#ret + 1] = { Snacks.picker.util.align(" ", 40 - offset) }
    vim.list_extend(ret, M.filename(item, picker))
  end
  return ret
end

---@param opts snacks.picker.ui_select.Opts
---@return snacks.picker.format
function M.ui_select(opts)
  return function(item, picker)
    local count = picker:count()
    local ret = {} ---@type snacks.picker.Highlight[]
    local idx = tostring(item.idx)
    idx = (" "):rep(#tostring(count) - #idx) .. idx
    ret[#ret + 1] = { idx .. ".", "SnacksPickerIdx" }
    ret[#ret + 1] = { " " }

    if opts.kind == "codeaction" then
      ---@type lsp.Command|lsp.CodeAction, lsp.HandlerContext
      local action, ctx = item.item.action, item.item.ctx
      local client = vim.lsp.get_client_by_id(ctx.client_id)
      ret[#ret + 1] = { action.title }
      if client then
        ret[#ret + 1] = { " " }
        ret[#ret + 1] = { ("[%s]"):format(client.name), "SnacksPickerSpecial" }
      end
    elseif opts.kind == "snacks" and opts.format_item then
      local t = opts.format_item(item.item, true)
      if type(t) == "string" then
        ret[#ret + 1] = { t }
      elseif type(t) == "table" then
        vim.list_extend(ret, t)
      end
    else
      ret[#ret + 1] = { item.formatted }
    end
    return ret
  end
end

function M.lines(item)
  local ret = {} ---@type snacks.picker.Highlight[]
  local line_count = vim.api.nvim_buf_line_count(item.buf)
  local idx = Snacks.picker.util.align(tostring(item.idx), #tostring(line_count), { align = "right" })
  ret[#ret + 1] = { idx, "LineNr", virtual = true }
  ret[#ret + 1] = { "  ", virtual = true }
  ret[#ret + 1] = { item.text }

  local offset = #idx + 2

  for _, extmark in ipairs(item.highlights or {}) do
    extmark = vim.deepcopy(extmark)
    if type(extmark[1]) ~= "string" then
      ---@cast extmark snacks.picker.Extmark
      extmark.col = extmark.col + offset
      if extmark.end_col then
        extmark.end_col = extmark.end_col + offset
      end
    end
    ret[#ret + 1] = extmark
  end
  return ret
end

function M.text(item, picker)
  local ret = {} ---@type snacks.picker.Highlight[]
  local ft = item.ft or picker.opts.formatters.text.ft
  if ft then
    Snacks.picker.highlight.format(item, item.text, ret, { lang = ft })
  else
    ret[#ret + 1] = { item.text, item.text_hl }
  end
  return ret
end

function M.command(item)
  local ret = {} ---@type snacks.picker.Highlight[]
  ret[#ret + 1] = { item.cmd, "SnacksPickerCmd" .. (item.cmd:find("^[a-z]") and "Builtin" or "") }
  if item.desc then
    ret[#ret + 1] = { " " }
    ret[#ret + 1] = { item.desc, "SnacksPickerDesc" }
  end
  return ret
end

function M.diagnostic(item, picker)
  local ret = {} ---@type snacks.picker.Highlight[]
  local diag = item.item ---@type vim.Diagnostic
  if item.severity then
    vim.list_extend(ret, M.severity(item, picker))
  end

  local message = diag.message
  ret[#ret + 1] = { message }
  Snacks.picker.highlight.markdown(ret)
  ret[#ret + 1] = { " " }

  if diag.source then
    ret[#ret + 1] = { diag.source, "SnacksPickerDiagnosticSource" }
    ret[#ret + 1] = { " " }
  end

  if diag.code then
    ret[#ret + 1] = { ("(%s)"):format(diag.code), "SnacksPickerDiagnosticCode" }
    ret[#ret + 1] = { " " }
  end
  vim.list_extend(ret, M.filename(item, picker))
  return ret
end

function M.autocmd(item)
  local ret = {} ---@type snacks.picker.Highlight[]
  ---@type vim.api.keyset.get_autocmds.ret
  local au = item.item
  local a = Snacks.picker.util.align
  ret[#ret + 1] = { a(au.event, 15), "SnacksPickerAuEvent" }
  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { a(au.pattern, 10), "SnacksPickerAuPattern" }
  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { a(tostring(au.group_name or ""), 15), "SnacksPickerAuGroup" }
  ret[#ret + 1] = { " " }
  if au.command ~= "" then
    Snacks.picker.highlight.format(item, au.command, ret, { lang = "vim" })
  else
    ret[#ret + 1] = { "callback", "Function" }
  end
  return ret
end

function M.hl(item)
  local ret = {} ---@type snacks.picker.Highlight[]
  ret[#ret + 1] = { item.hl_group, item.hl_group }
  return ret
end

function M.man(item)
  local a = Snacks.picker.util.align
  local ret = {} ---@type snacks.picker.Highlight[]
  ret[#ret + 1] = { a(item.page, 20), "SnacksPickerManPage" }
  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { ("(%s)"):format(item.section), "SnacksPickerManSection" }
  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { item.desc, "SnacksPickerManDesc" }
  return ret
end

-- Pretty keymaps using which-key icons when available
function M.keymap(item, picker)
  local ret = {} ---@type snacks.picker.Highlight[]
  ---@type vim.api.keyset.get_keymap
  local k = item.item
  local a = Snacks.picker.util.align

  if package.loaded["which-key"] then
    local Icons = require("which-key.icons")
    local icon, hl = Icons.get({ keymap = k, desc = k.desc })
    if icon then
      ret[#ret + 1] = { a(icon, 3), hl }
    else
      ret[#ret + 1] = { "   " }
    end
  end
  local lhs = Snacks.util.normkey(k.lhs)
  ret[#ret + 1] = { k.mode, "SnacksPickerKeymapMode" }
  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { a(lhs, 15), "SnacksPickerKeymapLhs" }
  ret[#ret + 1] = { " " }
  local icon_nowait = picker.opts.icons.keymaps.nowait

  if k.nowait == 1 then
    ret[#ret + 1] = { icon_nowait, "SnacksPickerKeymapNowait" }
  else
    ret[#ret + 1] = { (" "):rep(vim.api.nvim_strwidth(icon_nowait)) }
  end
  ret[#ret + 1] = { " " }

  if k.buffer and k.buffer > 0 then
    ret[#ret + 1] = { a("buf:" .. k.buffer, 6), "SnacksPickerBufNr" }
  else
    ret[#ret + 1] = { a("", 6) }
  end
  ret[#ret + 1] = { " " }

  local rhs_len = 0
  if k.rhs and k.rhs ~= "" then
    local rhs = k.rhs or ""
    rhs_len = #rhs
    local cmd = rhs:lower():find("<cmd>")
    if cmd then
      ret[#ret + 1] = { rhs:sub(1, cmd + 4), "NonText" }
      rhs = rhs:sub(cmd + 5)
      local cr = rhs:lower():find("<cr>$")
      if cr then
        rhs = rhs:sub(1, cr - 1)
      end
      Snacks.picker.highlight.format(item, rhs, ret, { lang = "vim" })
      if cr then
        ret[#ret + 1] = { "<CR>", "NonText" }
      end
    elseif rhs:lower():find("^<plug>") then
      ret[#ret + 1] = { "<Plug>", "NonText" }
      local plug = rhs:sub(7):gsub("^%(", ""):gsub("%)$", "")
      ret[#ret + 1] = { "(", "SnacksPickerDelim" }
      Snacks.picker.highlight.format(item, plug, ret, { lang = "vim" })
      ret[#ret + 1] = { ")", "SnacksPickerDelim" }
    elseif rhs:find("v:lua%.") then
      ret[#ret + 1] = { "v:lua", "NonText" }
      ret[#ret + 1] = { ".", "SnacksPickerDelim" }
      Snacks.picker.highlight.format(item, rhs:sub(7), ret, { lang = "lua" })
    else
      ret[#ret + 1] = { k.rhs, "SnacksPickerKeymapRhs" }
    end
  else
    ret[#ret + 1] = { "callback", "Function" }
    rhs_len = 8
  end

  if rhs_len < 15 then
    ret[#ret + 1] = { (" "):rep(15 - rhs_len) }
  end

  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { a(k.desc or "", 20) }

  if item.file then
    ret[#ret + 1] = { " " }
    vim.list_extend(ret, M.filename(item, picker))
  end
  return ret
end

function M.git_status(item, picker)
  local ret = {} ---@type snacks.picker.Highlight[]
  local a = Snacks.picker.util.align
  local s = vim.trim(item.status):sub(1, 1)
  local hls = {
    ["A"] = "SnacksPickerGitStatusAdded",
    ["M"] = "SnacksPickerGitStatusModified",
    ["D"] = "SnacksPickerGitStatusDeleted",
    ["R"] = "SnacksPickerGitStatusRenamed",
    ["C"] = "SnacksPickerGitStatusCopied",
    ["?"] = "SnacksPickerGitStatusUntracked",
  }
  local hl = hls[s] or "SnacksPickerGitStatus"
  ret[#ret + 1] = { a(item.status, 2, { align = "right" }), hl }
  ret[#ret + 1] = { " " }
  if item.rename then
    local file = item.file
    item.file = item.rename
    item._path = nil
    vim.list_extend(ret, M.filename(item, picker))
    item.file = file
    item._path = nil
    ret[#ret + 1] = { "-> ", "SnacksPickerDelim" }
    ret[#ret + 1] = { " " }
  end
  vim.list_extend(ret, M.filename(item, picker))
  return ret
end

function M.file_git_status(item, picker)
  local ret = {} ---@type snacks.picker.Highlight[]
  local status = require("snacks.picker.source.git").git_status(item.status)

  local hl = "SnacksPickerGitStatus"
  if status.unmerged then
    hl = "SnacksPickerGitStatusUnmerged"
  elseif status.staged then
    hl = "SnacksPickerGitStatusStaged"
  else
    hl = "SnacksPickerGitStatus" .. status.status:sub(1, 1):upper() .. status.status:sub(2)
  end

  if picker.opts.formatters.file.git_status_hl then
    item.filename_hl = hl
  end

  local icon = status.status:sub(1, 1):upper()
  icon = status.status == "untracked" and "?" or status.status == "ignored" and "!" or icon
  if picker.opts.icons.git.enabled then
    icon = picker.opts.icons.git[status.status] or icon --[[@as string]]
    if status.staged then
      icon = picker.opts.icons.git.staged
    end
  end

  ret[#ret + 1] = {
    col = 0,
    virt_text = { { icon, hl }, { " " } },
    virt_text_pos = "right_align",
    hl_mode = "combine",
  }
  return ret
end

function M.register(item)
  local ret = {} ---@type snacks.picker.Highlight[]
  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { "[", "SnacksPickerDelim" }
  ret[#ret + 1] = { item.reg, "SnacksPickerRegister" }
  ret[#ret + 1] = { "]", "SnacksPickerDelim" }
  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { item.value }
  return ret
end

function M.buffer(item, picker)
  local ret = {} ---@type snacks.picker.Highlight[]
  ret[#ret + 1] = { Snacks.picker.util.align(tostring(item.buf), 3), "SnacksPickerBufNr" }
  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { Snacks.picker.util.align(item.flags, 2, { align = "right" }), "SnacksPickerBufFlags" }
  ret[#ret + 1] = { " " }
  vim.list_extend(ret, M.filename(item, picker))
  return ret
end

function M.selected(item, picker)
  local a = Snacks.picker.util.align
  local selected = picker.opts.icons.ui.selected
  local unselected = picker.opts.icons.ui.unselected
  local width = math.max(vim.api.nvim_strwidth(selected), vim.api.nvim_strwidth(unselected))
  local ret = {} ---@type snacks.picker.Highlight[]
  if picker.list:is_selected(item) then
    ret[#ret + 1] = { a(selected, width), "SnacksPickerSelected", virtual = true }
  elseif picker.opts.formatters.selected.unselected then
    ret[#ret + 1] = { a(unselected, width), "SnacksPickerUnselected", virtual = true }
  else
    ret[#ret + 1] = { a("", width) }
  end
  return ret
end

function M.debug(item, picker)
  local score = item.score
  if not picker.matcher.sorting then
    score = picker.matcher.DEFAULT_SCORE
    if item.score_add then
      score = score + item.score_add
    end
    if item.score_mul then
      score = score * item.score_mul
    end
  end
  local ret = {} ---@type snacks.picker.Highlight[]
  ret[#ret + 1] = { ("%.2f "):format(score), "Number" }
  return ret
end

function M.icon(item, picker)
  local a = Snacks.picker.util.align
  ---@cast item snacks.picker.Icon
  local ret = {} ---@type snacks.picker.Highlight[]

  ret[#ret + 1] = { a(item.icon, 2), "SnacksPickerIcon" }
  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { a(item.source, 10), "SnacksPickerIconSource" }
  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { a(item.name, 30), "SnacksPickerIconName" }
  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { a(item.category, 8), "SnacksPickerIconCategory" }
  return ret
end

function M.notification(item, picker)
  local a = Snacks.picker.util.align
  local ret = {} ---@type snacks.picker.Highlight[]
  local notif = item.item ---@type snacks.notifier.Notif
  ret[#ret + 1] = { a(os.date("%R", notif.added), 5), "SnacksPickerTime" }
  ret[#ret + 1] = { " " }
  if item.severity then
    vim.list_extend(ret, M.severity(item, picker))
  end
  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { a(notif.title or "", 15), "SnacksNotifierHistoryTitle" }
  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { notif.msg, "SnacksPickerNotificationMessage" }
  Snacks.picker.highlight.markdown(ret)
  -- ret[#ret + 1] = { " " }
  return ret
end

return M
