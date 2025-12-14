local M = {}

---@class snacks.picker.history.Config: snacks.picker.Config
---@field name string

function M.commands()
  local commands = vim.api.nvim_get_commands({})
  for k, v in pairs(vim.api.nvim_buf_get_commands(0, {})) do
    if type(k) == "string" then -- fixes vim.empty_dict() bug
      commands[k] = v
    end
  end
  for _, c in ipairs(vim.fn.getcompletion("", "command")) do
    if not commands[c] and c:find("^[a-z]") then
      commands[c] = { definition = "completion" }
    end
  end
  ---@async
  ---@param cb async fun(item: snacks.picker.finder.Item)
  return function(cb)
    ---@type string[]
    local names = vim.tbl_keys(commands)
    table.sort(names)
    for _, name in pairs(names) do
      local def = commands[name]
      cb({
        text = name,
        desc = def.script_id and def.script_id < 0 and def.definition or nil,
        command = def,
        cmd = name,
        preview = {
          text = vim.inspect(def),
          ft = "lua",
        },
      })
    end
  end
end

---@param opts snacks.picker.history.Config
function M.history(opts)
  local count = vim.fn.histnr(opts.name)
  local items = {}
  for i = count, 1, -1 do
    local line = vim.fn.histget(opts.name, i)
    if not line:find("^%s*$") then
      table.insert(items, {
        text = line,
        cmd = line,
        preview = {
          text = line,
          ft = "text",
        },
      })
    end
  end
  return items
end

---@param opts snacks.picker.marks.Config
---@type snacks.picker.finder
function M.marks(opts, ctx)
  local marks = {} ---@type vim.fn.getmarklist.ret.item[]
  local current_buf = ctx.filter.current_buf
  if opts.global then
    vim.list_extend(marks, vim.fn.getmarklist())
  end
  if opts["local"] then
    vim.list_extend(marks, vim.fn.getmarklist(current_buf))
  end

  ---@type snacks.picker.finder.Item[]
  local items = {}
  local bufname = vim.api.nvim_buf_get_name(current_buf)
  for _, mark in ipairs(marks) do
    local file = mark.file or bufname
    local buf = mark.pos[1] and mark.pos[1] > 0 and mark.pos[1] or nil
    local line ---@type string?
    if buf and mark.pos[2] > 0 and vim.api.nvim_buf_is_valid(mark.pos[1]) then
      line = vim.api.nvim_buf_get_lines(buf, mark.pos[2] - 1, mark.pos[2], false)[1]
    end
    local label = mark.mark:sub(2, 2)
    items[#items + 1] = {
      text = table.concat({ label, file, line }, " "),
      label = label,
      line = line,
      buf = buf,
      file = file,
      pos = mark.pos[2] > 0 and { mark.pos[2], mark.pos[3] },
    }
  end
  table.sort(items, function(a, b)
    return a.label < b.label
  end)
  return items
end

function M.jumps()
  local jumps = vim.fn.getjumplist()[1]
  local items = {} ---@type snacks.picker.finder.Item[]
  for _, jump in ipairs(jumps) do
    local buf = jump.bufnr and vim.api.nvim_buf_is_valid(jump.bufnr) and jump.bufnr or 0
    local file = jump.filename or buf and vim.api.nvim_buf_get_name(buf) or nil
    if buf or file then
      local line ---@type string?
      if buf then
        line = vim.api.nvim_buf_get_lines(buf, jump.lnum - 1, jump.lnum, false)[1]
      end
      local label = tostring(#jumps - #items)
      table.insert(items, 1, {
        label = Snacks.picker.util.align(label, #tostring(#jumps), { align = "right" }),
        buf = buf,
        line = line,
        text = table.concat({ file, line }, " "),
        file = file,
        pos = jump.lnum and jump.lnum > 0 and { jump.lnum, jump.col } or nil,
      })
    end
  end
  return items
end

function M.autocmds()
  local autocmds = vim.api.nvim_get_autocmds({})
  local items = {} ---@type snacks.picker.finder.Item[]
  for _, au in ipairs(autocmds) do
    local item = au --[[@as snacks.picker.finder.Item]]
    item.text = Snacks.picker.util.text(item, { "event", "group_name", "pattern", "command" })
    item.preview = {
      text = vim.inspect(au),
      ft = "lua",
    }
    item.item = au
    if au.callback then
      local info = debug.getinfo(au.callback, "S")
      if info.what == "Lua" then
        item.file = info.source:sub(2)
        item.pos = { info.linedefined, 0 }
        item.preview = "file"
      end
    end
    items[#items + 1] = item
  end
  return items
end

function M.highlights()
  local hls = vim.api.nvim_get_hl(0, {}) --[[@as table<string,vim.api.keyset.get_hl_info> ]]
  local items = {} ---@type snacks.picker.finder.Item[]
  for group, hl in pairs(hls) do
    local defs = {} ---@type {group:string, hl:vim.api.keyset.get_hl_info}[]
    defs[#defs + 1] = { group = group, hl = hl }
    local link = hl.link
    local done = { [group] = true } ---@type table<string, boolean>
    while link and not done[link] do
      done[link] = true
      local hl_link = hls[link]
      if hl_link then
        defs[#defs + 1] = { group = link, hl = hl_link }
        link = hl_link.link
      else
        break
      end
    end
    local code = {} ---@type string[]
    local extmarks = {} ---@type snacks.picker.Extmark[]
    local row = 1
    for _, def in ipairs(defs) do
      for _, prop in ipairs({ "fg", "bg", "sp" }) do
        local v = def.hl[prop]
        if type(v) == "number" then
          def.hl[prop] = ("#%06X"):format(v)
        end
      end
      code[#code + 1] = ("%s = %s"):format(def.group, vim.inspect(def.hl))
      extmarks[#extmarks + 1] = { row = row, col = 0, hl_group = def.group, end_col = #def.group }
      row = row + #vim.split(code[#code], "\n") + 1
    end
    items[#items + 1] = {
      text = vim.inspect(defs):gsub("\n", " "),
      hl_group = group,
      preview = {
        text = table.concat(code, "\n\n"),
        ft = "lua",
        extmarks = extmarks,
      },
    }
  end
  table.sort(items, function(a, b)
    return a.hl_group < b.hl_group
  end)
  return items
end

function M.colorschemes()
  local items = {} ---@type snacks.picker.finder.Item[]
  local rtp = vim.o.runtimepath
  if package.loaded.lazy then
    rtp = rtp .. "," .. table.concat(require("lazy.core.util").get_unloaded_rtp(""), ",")
  end
  local files = vim.fn.globpath(rtp, "colors/*", false, true) ---@type string[]
  for _, file in ipairs(files) do
    local name = vim.fn.fnamemodify(file, ":t:r")
    local ext = vim.fn.fnamemodify(file, ":e")
    if ext == "vim" or ext == "lua" then
      items[#items + 1] = {
        text = name,
        file = file,
      }
    end
  end
  return items
end

---@param opts snacks.picker.keymaps.Config
function M.keymaps(opts)
  local items = {} ---@type snacks.picker.finder.Item[]
  local maps = {} ---@type vim.api.keyset.get_keymap[]
  for _, mode in ipairs(opts.modes) do
    if opts.global then
      vim.list_extend(maps, vim.api.nvim_get_keymap(mode))
    end
    if opts["local"] then
      vim.list_extend(maps, vim.api.nvim_buf_get_keymap(0, mode))
    end
  end
  local done = {} ---@type table<string, boolean>
  for _, km in ipairs(maps) do
    local key = Snacks.picker.util.text(km, { "mode", "lhs", "buffer" })
    local keep = true
    if opts.plugs == false and km.lhs:match("^<Plug>") then
      keep = false
    end
    if keep and not done[key] then
      done[key] = true
      local item = {
        mode = km.mode,
        item = km,
        key = km.lhs,
        preview = {
          text = vim.inspect(km),
          ft = "lua",
        },
      }
      if km.callback then
        local info = debug.getinfo(km.callback, "S")
        item.info = info
        if info.what == "Lua" then
          local source = info.source:sub(2)
          item.file = source:gsub("^vim/", vim.env.VIMRUNTIME .. "/lua/vim/")
          if source:find("^vim/") and info.linedefined == 0 then
            item.search = "/vim\\.keymap\\.set.*['\"]" .. km.lhs
          else
            item.pos = { info.linedefined, 0 }
          end
          item.preview = "file"
        end
      end
      item.text = Snacks.util.normkey(km.lhs)
        .. " "
        .. Snacks.picker.util.text(km, { "mode", "lhs", "rhs", "desc" })
        .. (item.file or "")
      items[#items + 1] = item
    end
  end
  return items
end

function M.registers()
  local registers = '*+"-:.%/#=_abcdefghijklmnopqrstuvwxyz0123456789'
  local items = {} ---@type snacks.picker.finder.Item[]
  local is_osc52 = vim.g.clipboard and vim.g.clipboard.name == "OSC 52"
  local has_clipboard = vim.g.loaded_clipboard_provider == 2
  for i = 1, #registers, 1 do
    local reg = registers:sub(i, i)
    local value = ""
    if is_osc52 and reg:match("[%+%*]") then
      value = "OSC 52 detected, register not checked to maintain compatibility"
    elseif has_clipboard or not reg:match("[%+%*]") then
      local ok, reg_value = pcall(vim.fn.getreg, reg, 1)
      value = (ok and reg_value or "") --[[@as string]]
    end
    if value ~= "" then
      table.insert(items, {
        text = ("%s: %s"):format(reg, value:gsub("\n", "\\n"):gsub("\r", "\\r")),
        reg = reg,
        label = reg,
        data = value,
        value = value:gsub("\n", "\\n"):gsub("\r", "\\r"),
        preview = {
          text = value,
          ft = "text",
        },
      })
    end
  end
  return items
end

function M.spelling()
  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_buf_get_lines(buf, cursor[1] - 1, cursor[1], false)[1]

  -- get a misspelled word from under the cursor, if not found, then use the cursor_word instead
  local bad = vim.fn.spellbadword() ---@type string[]
  local word = bad[1] == "" and vim.fn.expand("<cword>") or bad[1]
  local suggestions = vim.fn.spellsuggest(word, 25, bad[2] == "caps")

  local items = {} ---@type snacks.picker.finder.Item[]

  for _, label in ipairs(suggestions) do
    table.insert(items, {
      text = label,
      action = function()
        -- skip whitespace
        local col = cursor[2] + 1
        while line:sub(col, col):match("%s") and col < #line do
          col = col + 1
          vim.api.nvim_win_set_cursor(win, { cursor[1], col - 1 })
        end
        vim.cmd('normal! "_ciw' .. label)
      end,
    })
  end
  return items
end

---@class snacks.picker.tags.Tag
---@field name string
---@field filename string
---@field cmd string
---@field kind? string
---@field static? string

---@param opts snacks.picker.tags.Config
---@type snacks.picker.finder
function M.tags(opts, ctx)
  local buf = ctx.filter.current_buf
  ---@type snacks.picker.tags.Tag[]
  local tags = vim.fn.taglist(ctx.filter.search == "" and ".*" or ctx.filter.search, vim.api.nvim_buf_get_name(buf))
  local ret = {} ---@type snacks.picker.finder.Item[]

  local lsp_kinds = {
    c = "Class",
    d = "Constant",
    e = "Enum",
    f = "Function",
    g = "EnumMember",
    l = "Variable",
    m = "Method",
    s = "Struct",
    t = "TypeParameter",
    v = "Variable",
    F = "Field",
    M = "Module",
    n = "Namespace",
    P = "Property",
    S = "Struct",
    T = "TypeParameter",
  }

  for _, tag in ipairs(tags) do
    ---@type snacks.picker.finder.Item
    local item = {
      text = tag.name,
      name = tag.name,
      file = tag.filename,
      search = tag.cmd,
      kind = tag.kind,
      lsp_kind = lsp_kinds[tag.kind] or "Text",
    }
    ret[#ret + 1] = item
  end

  return ret
end

---@param opts snacks.picker.undo.Config
---@type snacks.picker.finder
function M.undo(opts, ctx)
  local tree = vim.fn.undotree()
  local buf = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(buf)
  local items = {} ---@type snacks.picker.finder.Item[]
  local diff_fn = vim.text and vim.text.diff or vim.diff

  -- Copy the current buffer to a temporary file and load the undo history.
  -- This is done to prevent the current buffer from being modified,
  -- and is way better for performance, since LSP change tracking won't be triggered
  local tmp_file = vim.fn.stdpath("cache") .. "/snacks-undo"
  local tmp_undo = tmp_file .. ".undo"
  local tmpbuf = vim.fn.bufadd(tmp_file)
  vim.bo[tmpbuf].swapfile = false
  vim.fn.writefile(vim.api.nvim_buf_get_lines(buf, 0, -1, false), tmp_file)
  vim.fn.bufload(tmpbuf)
  vim.api.nvim_buf_call(buf, function()
    vim.cmd("silent wundo! " .. tmp_undo)
  end)
  vim.api.nvim_buf_call(tmpbuf, function()
    pcall(vim.cmd, "silent rundo " .. tmp_undo)
  end)

  ---@param item snacks.picker.finder.Item
  local function resolve(item)
    local entry = item.item ---@type vim.fn.undotree.entry
    ---@type string[], string[]
    local before, after = {}, {}

    local ei = vim.o.eventignore
    vim.o.eventignore = "all"
    vim.api.nvim_buf_call(tmpbuf, function()
      -- state after the undo
      vim.cmd("noautocmd silent undo " .. entry.seq)
      after = vim.api.nvim_buf_get_lines(tmpbuf, 0, -1, false)
      -- state before the undo
      vim.cmd("noautocmd silent undo")
      before = vim.api.nvim_buf_get_lines(tmpbuf, 0, -1, false)
    end)
    vim.o.eventignore = ei

    local diff = diff_fn(table.concat(before, "\n") .. "\n", table.concat(after, "\n") .. "\n", opts.diff) --[[@as string]]
    local changes = {} ---@type string[]
    local added_lines = {} ---@type string[]
    local removed_lines = {} ---@type string[]

    for _, line in ipairs(vim.split(diff, "\n")) do
      if line:sub(1, 1) == "+" then
        changes[#changes + 1] = line:sub(2)
        added_lines[#added_lines + 1] = line:sub(2)
      elseif line:sub(1, 1) == "-" then
        changes[#changes + 1] = line:sub(2)
        removed_lines[#removed_lines + 1] = line:sub(2)
      end
    end
    diff = Snacks.picker.util.tpl(
      "diff --git a/{file} b/{file}\n--- {file}\n+++ {file}\n{diff}",
      { file = vim.fn.fnamemodify(file, ":."), diff = diff }
    )
    item.text = table.concat(changes, " ")
    item.data = table.concat(added_lines, "\n")
    item.added_lines = table.concat(added_lines, "\n")
    item.removed_lines = table.concat(removed_lines, "\n")
    item.added = #added_lines
    item.removed = #removed_lines
    item.diff = diff
  end

  ---@param entries? vim.fn.undotree.entry[]
  ---@param parent? snacks.picker.finder.Item
  local function add(entries, parent)
    entries = entries or {}
    table.sort(entries, function(a, b)
      return a.seq < b.seq
    end)
    local last ---@type snacks.picker.finder.Item?
    for e, entry in ipairs(entries) do
      add(entry.alt, last or parent)
      local item = {
        seq = entry.seq,
        buf = buf,
        resolve = resolve,
        file = file,
        item = entry,
        current = entry.seq == tree.seq_cur,
        parent = parent,
        last = e == #entries,
        action = function()
          vim.api.nvim_buf_call(buf, function()
            vim.cmd("undo " .. entry.seq)
          end)
        end,
      }
      items[#items + 1] = item
      last = item
    end
  end
  add(tree.entries)

  -- Resolve the items in batches to prevent blocking the UI
  ---@param cb async fun(item: snacks.picker.finder.Item)
  ---@async
  return function(cb)
    ctx.async:on("done", function()
      vim.schedule(function()
        -- Clean up the temporary files
        vim.api.nvim_buf_delete(tmpbuf, { force = true })
        vim.fn.delete(tmp_file)
        vim.fn.delete(tmp_undo)
      end)
    end)
    for i = #items, 1, -1 do
      local item = items[i]
      cb(item)
      if item.current then
        ctx.picker.list:set_target(#items - i + 1)
      end
    end

    while #items > 0 do
      vim.schedule(function()
        local count = 0
        while #items > 0 and count < 5 do
          count = count + 1
          local item = table.remove(items, 1)
          Snacks.picker.util.resolve(item)
        end
        ctx.async:resume()
      end)
      ctx.async:suspend()
    end
  end
end

return M
