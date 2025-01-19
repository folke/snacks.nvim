local M = {}

---@class snacks.picker
---@field commands fun(opts?: snacks.picker.Config): snacks.Picker
---@field marks fun(opts?: snacks.picker.marks.Config): snacks.Picker
---@field jumps fun(opts?: snacks.picker.Config): snacks.Picker
---@field autocmds fun(opts?: snacks.picker.Config): snacks.Picker
---@field highlights fun(opts?: snacks.picker.Config): snacks.Picker
---@field colorschemes fun(opts?: snacks.picker.Config): snacks.Picker
---@field keymaps fun(opts?: snacks.picker.Config): snacks.Picker
---@field registers fun(opts?: snacks.picker.Config): snacks.Picker
---@field command_history fun(opts?: snacks.picker.history.Config): snacks.Picker
---@field search_history fun(opts?: snacks.picker.history.Config): snacks.Picker

---@class snacks.picker.history.Config: snacks.picker.Config
---@field name string

function M.commands()
  local commands = vim.api.nvim_get_commands({})
  for k, v in pairs(vim.api.nvim_buf_get_commands(0, {})) do
    if type(k) == "string" then -- fixes vim.empty_dict() bug
      commands[k] = v
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
function M.marks(opts)
  local marks = {} ---@type vim.fn.getmarklist.ret.item[]
  if opts.global then
    vim.list_extend(marks, vim.fn.getmarklist())
  end
  if opts["local"] then
    vim.list_extend(marks, vim.fn.getmarklist(vim.api.nvim_get_current_buf()))
  end

  ---@type snacks.picker.finder.Item[]
  local items = {}
  local bufname = vim.api.nvim_buf_get_name(0)
  for _, mark in ipairs(marks) do
    local file = mark.file or bufname
    local buf = mark.pos[1] and mark.pos[1] > 0 and mark.pos[1] or nil
    local line ---@type string?
    if buf and mark.pos[2] > 0 and vim.api.nvim_buf_is_valid(mark.pos[2]) then
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
  local files = vim.fn.globpath(rtp, "colors/*", true, true) ---@type string[]
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
    if not done[key] then
      done[key] = true
      local item = {
        mode = km.mode,
        item = km,
        preview = {
          text = vim.inspect(km),
          ft = "lua",
        },
      }
      if km.callback then
        local info = debug.getinfo(km.callback, "S")
        if info.what == "Lua" then
          item.file = info.source:sub(2)
          item.pos = { info.linedefined, 0 }
          item.preview = "file"
        end
      end
      item.text = Snacks.picker.util.text(km, { "mode", "lhs", "rhs", "desc" }) .. (item.file or "")
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

return M
