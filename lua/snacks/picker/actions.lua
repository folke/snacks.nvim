---@class snacks.picker.actions
---@field [string] snacks.picker.Action.spec
local M = {}

---@class snacks.picker.jump.Action: snacks.picker.Action
---@field cmd? snacks.picker.EditCmd

---@class snacks.picker.layout.Action: snacks.picker.Action
---@field layout? snacks.picker.layout.Config|string

---@class snacks.picker.yank.Action: snacks.picker.Action
---@field reg? string
---@field field? string
---@field notify? boolean

---@class snacks.picker.insert.Action: snacks.picker.Action
---@field expr string

---@enum (key) snacks.picker.EditCmd
local edit_cmd = {
  edit = "buffer",
  split = "sbuffer",
  vsplit = "vert sbuffer",
  tab = "tab sbuffer",
  drop = "drop",
  tabdrop = "tab drop",
}

function M.jump(picker, _, action)
  ---@cast action snacks.picker.jump.Action
  -- if we're still in insert mode, stop it and schedule
  -- it to prevent issues with cursor position
  if vim.fn.mode():sub(1, 1) == "i" then
    vim.cmd.stopinsert()
    vim.schedule(function()
      M.jump(picker, _, action)
    end)
    return
  end

  local items = picker:selected({ fallback = true })

  if picker.opts.jump.close then
    picker:close()
  else
    vim.api.nvim_set_current_win(picker.main)
  end

  if #items == 0 then
    return
  end

  local win = vim.api.nvim_get_current_win()

  local current_buf = vim.api.nvim_get_current_buf()
  local current_empty = vim.bo[current_buf].buftype == ""
    and vim.bo[current_buf].filetype == ""
    and vim.api.nvim_buf_line_count(current_buf) == 1
    and vim.api.nvim_buf_get_lines(current_buf, 0, -1, false)[1] == ""
    and vim.api.nvim_buf_get_name(current_buf) == ""

  if not current_empty then
    -- save position in jump list
    if picker.opts.jump.jumplist then
      vim.api.nvim_win_call(win, function()
        vim.cmd("normal! m'")
      end)
    end

    -- save position in tag stack
    if picker.opts.jump.tagstack then
      local from = vim.fn.getpos(".")
      from[1] = current_buf
      local tagstack = { { tagname = vim.fn.expand("<cword>"), from = from } }
      vim.fn.settagstack(vim.fn.win_getid(win), { items = tagstack }, "t")
    end
  end

  local cmd = edit_cmd[action.cmd] or "buffer"

  if cmd:find("drop") then
    local drop = {} ---@type string[]
    for _, item in ipairs(items) do
      local path = item.buf and vim.api.nvim_buf_get_name(item.buf) or Snacks.picker.util.path(item)
      if not path then
        Snacks.notify.error("Either item.buf or item.file is required", { title = "Snacks Picker" })
        return
      end
      drop[#drop + 1] = vim.fn.fnameescape(path)
    end
    vim.cmd(cmd .. " " .. table.concat(drop, " "))
  else
    for i, item in ipairs(items) do
      -- load the buffer
      local buf = item.buf ---@type number
      if not buf then
        local path = assert(Snacks.picker.util.path(item), "Either item.buf or item.file is required")
        buf = vim.fn.bufadd(path)
      end
      vim.bo[buf].buflisted = true

      -- use an existing window if possible
      if cmd == "buffer" and #items == 1 and picker.opts.jump.reuse_win and buf ~= current_buf then
        for _, w in ipairs(vim.fn.win_findbuf(buf)) do
          if vim.api.nvim_win_get_config(w).relative == "" then
            win = w
            vim.api.nvim_set_current_win(win)
            break
          end
        end
      end

      -- open the first buffer
      if i == 1 then
        vim.cmd(("%s %d"):format(cmd, buf))
        win = vim.api.nvim_get_current_win()
      end
    end
  end

  -- set the cursor
  local item = items[1]
  local pos = item.pos
  if picker.opts.jump.match then
    pos = picker.matcher:bufpos(vim.api.nvim_get_current_buf(), item) or pos
  end
  if pos and pos[1] > 0 then
    vim.api.nvim_win_set_cursor(win, { pos[1], pos[2] })
    vim.cmd("norm! zzzv")
  elseif item.search then
    vim.cmd(item.search)
    vim.cmd("noh")
  end

  -- HACK: this should fix folds
  if vim.wo.foldmethod == "expr" then
    vim.schedule(function()
      vim.opt.foldmethod = "expr"
    end)
  end

  if current_empty and vim.api.nvim_buf_is_valid(current_buf) then
    local w = vim.fn.win_findbuf(current_buf)
    if #w == 0 then
      vim.api.nvim_buf_delete(current_buf, { force = true })
    end
  end
end

function M.close(picker)
  picker:norm(function()
    picker:close()
  end)
end

function M.cancel(picker)
  picker:norm(function()
    local main = require("snacks.picker.core.main").new({ float = false, file = false })
    vim.api.nvim_set_current_win(main:get())
    picker:close()
  end)
end

M.confirm = M.jump -- default confirm action

M.split = { action = "confirm", cmd = "split" }
M.vsplit = { action = "confirm", cmd = "vsplit" }
M.tab = { action = "confirm", cmd = "tab" }
M.drop = { action = "confirm", cmd = "drop" }
M.tabdrop = { action = "confirm", cmd = "tabdrop" }

-- aliases
M.edit = M.jump
M.edit_split = M.split
M.edit_vsplit = M.vsplit
M.edit_tab = M.tab

function M.layout(picker, _, action)
  ---@cast action snacks.picker.layout.Action
  assert(action.layout, "Layout action requires a layout")
  local opts = type(action.layout) == "table" and { layout = action.layout } or action.layout
  ---@cast opts snacks.picker.Config
  local layout = Snacks.picker.config.layout(opts)
  picker:set_layout(layout)
  -- Adjust some options for split layouts
  if (layout.layout.position or "float") ~= "float" then
    picker.opts.auto_close = false
    picker.opts.jump.close = false
    picker:toggle("preview", { enable = false })
    picker.list.win:focus()
  end
end

M.layout_top = { action = "layout", layout = "top" }
M.layout_bottom = { action = "layout", layout = "bottom" }
M.layout_left = { action = "layout", layout = "left" }
M.layout_right = { action = "layout", layout = "right" }

function M.toggle_maximize(picker)
  picker.layout:maximize()
end

function M.insert(picker, _, action)
  ---@cast action snacks.picker.insert.Action
  if action.expr then
    local value = ""
    vim.api.nvim_buf_call(picker.input.filter.current_buf, function()
      value = action.expr == "line" and vim.api.nvim_get_current_line() or vim.fn.expand(action.expr)
    end)
    vim.api.nvim_win_call(picker.input.win.win, function()
      vim.api.nvim_put({ value }, "c", true, true)
    end)
  end
end
M.insert_cword = { action = "insert", expr = "<cword>" }
M.insert_cWORD = { action = "insert", expr = "<cWORD>" }
M.insert_filename = { action = "insert", expr = "%" }
M.insert_file = { action = "insert", expr = "<cfile>" }
M.insert_line = { action = "insert", expr = "line" }
M.insert_file_full = { action = "insert", expr = "<cfile>:p" }
M.insert_alt = { action = "insert", expr = "#" }

function M.toggle_preview(picker)
  picker:toggle("preview")
end

function M.toggle_input(picker)
  picker:toggle("input", { focus = true })
end

function M.picker_grep(_, item)
  if item then
    Snacks.picker.grep({ cwd = Snacks.picker.util.dir(item) })
  end
end

function M.terminal(_, item)
  if item then
    Snacks.terminal(nil, { cwd = Snacks.picker.util.dir(item) })
  end
end

function M.cd(_, item)
  if item then
    vim.fn.chdir(Snacks.picker.util.dir(item))
  end
end

function M.tcd(_, item)
  if item then
    vim.cmd.tcd(Snacks.picker.util.dir(item))
  end
end

function M.lcd(_, item)
  if item then
    vim.cmd.lcd(Snacks.picker.util.dir(item))
  end
end

function M.picker(picker, item, action)
  if not item then
    return
  end
  local source = action.source or "files"
  for _, p in ipairs(Snacks.picker.get({ source = source })) do
    p:close()
  end
  Snacks.picker(source, {
    cwd = Snacks.picker.util.dir(item),
    on_show = function()
      picker:close()
    end,
  })
end

M.picker_files = { action = "picker", source = "files" }
M.picker_explorer = { action = "picker", source = "explorer" }
M.picker_recent = { action = "picker", source = "recent" }

function M.pick_win(picker, item, action)
  if not picker.layout.split then
    picker.layout:hide()
  end
  local win = Snacks.picker.util.pick_win({ main = picker.main })
  if not win then
    if not picker.layout.split then
      picker.layout:unhide()
    end
    return true
  end
  picker.main = win
  if not picker.layout.split then
    vim.defer_fn(function()
      if not picker.closed then
        picker.layout:unhide()
      end
    end, 100)
  end
end

function M.bufdelete(picker)
  picker.preview:reset()
  local non_buf_delete_requested = false
  for _, item in ipairs(picker:selected({ fallback = true })) do
    if item.buf then
      Snacks.bufdelete.delete(item.buf)
    else
      non_buf_delete_requested = true
    end
  end
  if non_buf_delete_requested then
    Snacks.notify.warn("Only open buffers can be deleted", { title = "Snacks Picker" })
  end
  picker.list:set_selected()
  picker.list:set_target()
  picker:find()
end

function M.git_stage(picker)
  local items = picker:selected({ fallback = true })
  local done = 0
  for _, item in ipairs(items) do
    local cmd = item.status:sub(2) == " " and { "git", "restore", "--staged", item.file } or { "git", "add", item.file }
    Snacks.picker.util.cmd(cmd, function(data, code)
      done = done + 1
      if done == #items then
        picker.list:set_selected()
        picker.list:set_target()
        picker:find()
      end
    end, { cwd = item.cwd })
  end
end

function M.git_stash_apply(_, item)
  if not item then
    return
  end
  local cmd = { "git", "stash", "apply", item.stash }
  Snacks.picker.util.cmd(cmd, function()
    Snacks.notify("Stash applied: `" .. item.stash .. "`", { title = "Snacks Picker" })
  end, { cwd = item.cwd })
end

function M.git_checkout(picker, item)
  picker:close()
  if item then
    local what = item.branch or item.commit --[[@as string?]]
    if not what then
      Snacks.notify.warn("No branch or commit found", { title = "Snacks Picker" })
      return
    end
    local cmd = { "git", "checkout", what }
    local remote_branch = what:match("^remotes/[^/]+/(.+)$")
    if remote_branch then
      cmd = { "git", "checkout", "-b", remote_branch, what }
    end
    if item.file then
      vim.list_extend(cmd, { "--", item.file })
    end
    Snacks.picker.util.cmd(cmd, function()
      Snacks.notify("Checkout " .. what, { title = "Snacks Picker" })
      vim.cmd.checktime()
    end, { cwd = item.cwd })
  end
end

function M.git_branch_add(picker)
  Snacks.input.input({
    prompt = "New Branch Name",
    default = picker.input:get(),
  }, function(name)
    if (name or ""):match("^%s*$") then
      return
    end
    Snacks.picker.util.cmd({ "git", "branch", "--list", name }, function(data)
      if data[1] ~= "" then
        return Snacks.notify.error("Branch '" .. name .. "' already exists.", { title = "Snacks Picker" })
      end
      Snacks.picker.util.cmd({ "git", "checkout", "-b", name }, function()
        Snacks.notify("Created Branch `" .. name .. "`", { title = "Snacks Picker" })
        vim.cmd.checktime()
        picker.list:set_target()
        picker.input:set("", "")
        picker:find()
      end, { cwd = picker:cwd() })
    end, { cwd = picker:cwd() })
  end)
end

function M.git_branch_del(picker, item)
  if not (item and item.branch) then
    Snacks.notify.warn("No branch or commit found", { title = "Snacks Picker" })
  end

  local branch = item.branch
  Snacks.picker.util.cmd({ "git", "rev-parse", "--abbrev-ref", "HEAD" }, function(data)
    -- Check if we are on the same branch
    if data[1]:match(branch) ~= nil then
      Snacks.notify.error("Cannot delete the current branch.", { title = "Snacks Picker" })
      return
    end

    Snacks.picker.select({ "Yes", "No" }, { prompt = ("Delete branch %q?"):format(branch) }, function(_, idx)
      if idx == 1 then
        -- Proceed with deletion
        Snacks.picker.util.cmd({ "git", "branch", "-d", branch }, function()
          Snacks.notify("Deleted Branch `" .. branch .. "`", { title = "Snacks Picker" })
          vim.cmd.checktime()
          picker.list:set_selected()
          picker.list:set_target()
          picker:find()
        end, { cwd = picker:cwd() })
      end
    end)
  end, { cwd = picker:cwd() })
end

---@param items snacks.picker.Item[]
---@param opts? {win?:number}
local function setqflist(items, opts)
  local qf = {} ---@type vim.quickfix.entry[]
  for _, item in ipairs(items) do
    qf[#qf + 1] = {
      filename = Snacks.picker.util.path(item),
      bufnr = item.buf,
      lnum = item.pos and item.pos[1] or 1,
      col = item.pos and item.pos[2] + 1 or 1,
      end_lnum = item.end_pos and item.end_pos[1] or nil,
      end_col = item.end_pos and item.end_pos[2] + 1 or nil,
      text = item.line or item.comment or item.label or item.name or item.detail or item.text,
      pattern = item.search,
      type = ({ "E", "W", "I", "N" })[item.severity],
      valid = true,
    }
  end
  if opts and opts.win then
    vim.fn.setloclist(opts.win, qf)
    vim.cmd("botright lopen")
  else
    vim.fn.setqflist(qf)
    vim.cmd("botright copen")
  end
end

--- Send selected or all items to the quickfix list.
function M.qflist(picker)
  picker:close()
  local sel = picker:selected()
  local items = #sel > 0 and sel or picker:items()
  setqflist(items)
end

--- Send all items to the quickfix list.
function M.qflist_all(picker)
  picker:close()
  setqflist(picker:items())
end

--- Send selected or all items to the location list.
function M.loclist(picker)
  picker:close()
  local sel = picker:selected()
  local items = #sel > 0 and sel or picker:items()
  setqflist(items, { win = picker.main })
end

function M.yank(picker, item, action)
  ---@cast action snacks.picker.yank.Action
  if item then
    local reg = action.reg or vim.v.register
    local value = item[action.field] or item.data or item.text
    vim.fn.setreg(reg, value)
    if action.notify ~= false then
      local buf = item.buf or vim.api.nvim_win_get_buf(picker.main)
      local ft = vim.bo[buf].filetype
      Snacks.notify(("Yanked to register `%s`:\n```%s\n%s\n```"):format(reg, ft, value), { title = "Snacks Picker" })
    end
  end
end
M.copy = M.yank

function M.put(picker, item, action)
  ---@cast action snacks.picker.yank.Action
  picker:close()
  if item then
    local value = item[action.field] or item.data or item.text
    vim.api.nvim_put({ value }, "", true, true)
  end
end

function M.history_back(picker)
  picker:hist()
end

function M.history_forward(picker)
  picker:hist(true)
end

--- Toggles the selection of the current item,
--- and moves the cursor to the next item.
function M.select_and_next(picker)
  picker.list:select()
  picker.list:_move(vim.v.count1)
end

--- Toggles the selection of the current item,
--- and moves the cursor to the prev item.
function M.select_and_prev(picker)
  picker.list:select()
  picker.list:_move(-vim.v.count1)
end

--- Selects all items in the list.
--- Or clears the selection if all items are selected.
function M.select_all(picker)
  picker.list:select_all()
end

function M.cmd(picker, item)
  picker:close()
  if item and item.cmd then
    vim.schedule(function()
      vim.api.nvim_input(":")
      vim.schedule(function()
        vim.fn.setcmdline(item.cmd)
      end)
    end)
  end
end

function M.search(picker, item)
  picker:close()
  if item then
    vim.api.nvim_input("/")
    vim.schedule(function()
      vim.fn.setcmdline(item.text)
    end)
  end
end

--- Tries to load the session, if it fails, it will open the picker.
function M.load_session(picker, item)
  picker:close()
  if not item then
    return
  end
  local dir = item.file
  local session_loaded = false
  vim.api.nvim_create_autocmd("SessionLoadPost", {
    once = true,
    callback = function()
      session_loaded = true
    end,
  })
  vim.defer_fn(function()
    if not session_loaded then
      Snacks.picker.files()
    end
  end, 100)
  vim.fn.chdir(dir)
  local session = Snacks.dashboard.sections.session()
  if session then
    vim.cmd(session.action:sub(2))
  end
end

function M.help(picker, item, action)
  ---@cast action snacks.picker.jump.Action
  if item then
    picker:close()
    local file = Snacks.picker.util.path(item) or ""
    if package.loaded.lazy then
      local plugin = file:match("/([^/]+)/doc/")
      if plugin and require("lazy.core.config").plugins[plugin] then
        require("lazy").load({ plugins = { plugin } })
      end
    end

    local cmd = "help " .. item.text
    if action.cmd == "vsplit" then
      cmd = "vert " .. cmd
    elseif action.cmd == "tab" then
      cmd = "tab " .. cmd
    end
    vim.cmd(cmd)
  end
end

function M.toggle_help_input(picker)
  picker.input.win:toggle_help()
end

function M.toggle_help_list(picker)
  picker.list.win:toggle_help()
end

function M.preview_scroll_down(picker)
  if picker.preview.win:valid() then
    picker.preview.win:scroll()
  end
end

function M.preview_scroll_up(picker)
  if picker.preview.win:valid() then
    picker.preview.win:scroll(true)
  end
end

function M.preview_scroll_left(picker)
  if picker.preview.win:valid() then
    picker.preview.win:hscroll(true)
  end
end

function M.preview_scroll_right(picker)
  if picker.preview.win:valid() then
    picker.preview.win:hscroll()
  end
end

function M.inspect(picker, item)
  Snacks.debug.inspect(item)
end

function M.toggle_live(picker)
  if not picker.opts.supports_live then
    Snacks.notify.warn("Live search is not supported for `" .. picker.title .. "`", { title = "Snacks Picker" })
    return
  end
  picker.opts.live = not picker.opts.live
  picker.input:set()
  picker.input:update()
end

function M.toggle_focus(picker)
  if vim.api.nvim_get_current_win() == picker.input.win.win then
    picker:focus("list", { show = true })
  else
    picker:focus("input", { show = true })
  end
end

function M.cycle_win(picker)
  local wins = { picker.input.win.win, picker.preview.win.win, picker.list.win.win }
  wins = vim.tbl_filter(function(w)
    return vim.api.nvim_win_is_valid(w)
  end, wins)
  local win = vim.api.nvim_get_current_win()
  local idx = 1
  for i, w in ipairs(wins) do
    if w == win then
      idx = i
      break
    end
  end
  win = wins[idx % #wins + 1] or 1 -- cycle
  vim.api.nvim_set_current_win(win)
end

function M.focus_input(picker)
  picker:focus("input", { show = true })
end

function M.focus_list(picker)
  picker:focus("list", { show = true })
end

function M.focus_preview(picker)
  picker:focus("preview", { show = true })
end

function M.item_action(picker, item, action)
  if item.action then
    picker:norm(function()
      picker:close()
      item.action(picker, item, action)
    end)
  end
end

function M.list_top(picker)
  picker.list:move(1, true)
end

function M.list_bottom(picker)
  picker.list:move(picker.list:count(), true)
end

function M.list_down(picker)
  picker.list:move(vim.v.count1)
end

function M.list_up(picker)
  picker.list:move(-vim.v.count1)
end

function M.list_scroll_top(picker)
  local cursor = picker.list.cursor
  picker.list:view(cursor, cursor)
end

function M.list_scroll_bottom(picker)
  local cursor = picker.list.cursor
  picker.list:view(cursor, picker.list.cursor - picker.list:height() + 1)
end

function M.list_scroll_center(picker)
  local cursor = picker.list.cursor
  picker.list:view(cursor, picker.list.cursor - math.ceil(picker.list:height() / 2) + 1)
end

function M.list_scroll_down(picker)
  picker.list:scroll(picker.list.state.scroll)
end

function M.list_scroll_up(picker)
  picker.list:scroll(-picker.list.state.scroll)
end

return M
