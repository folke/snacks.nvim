---@class snacks.picker.actions
---@field [string] snacks.picker.Action.spec
local M = {}

---@class snacks.picker.jump.Action: snacks.picker.Action
---@field cmd? snacks.picker.EditCmd

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

      -- use an existing window if possible
      if #items == 1 and picker.opts.jump.reuse_win and buf ~= current_buf then
        win = vim.fn.win_findbuf(buf)[1] or win
        vim.api.nvim_set_current_win(win)
      end

      vim.bo[buf].buflisted = true

      -- open the first buffer
      if i == 1 then
        vim.cmd(("%s %d"):format(cmd, buf))
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
    local w = vim.fn.bufwinid(current_buf)
    if w == -1 then
      vim.api.nvim_buf_delete(current_buf, { force = true })
    end
  end
end

function M.close(picker)
  picker:close()
end

M.cancel = "close"
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

function M.toggle_maximize(picker)
  picker.layout:maximize()
end

function M.toggle_preview(picker)
  picker:toggle_preview()
end

function M.picker_grep(_, item)
  if item then
    Snacks.picker.grep({ cwd = Snacks.picker.util.dir(item) })
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

function M.picker_files(_, item)
  if item then
    Snacks.picker.files({ cwd = Snacks.picker.util.dir(item) })
  end
end

function M.picker_explorer(_, item)
  if item then
    local p = Snacks.picker.get({ source = "explorer" })[1]
    if p then
      p:close()
    end
    Snacks.picker.explorer({ cwd = Snacks.picker.util.dir(item) })
  end
end

function M.picker_recent(_, item)
  if item then
    Snacks.picker.recent({ filter = { cwd = Snacks.picker.util.dir(item) } })
  end
end

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
  local non_buf_delete_requested = false
  for _, item in ipairs(picker:selected({ fallback = true })) do
    if item.buf then
      Snacks.bufdelete.delete(item.buf)
    else
      non_buf_delete_requested = true
    end
    picker.list:unselect(item)
  end

  if non_buf_delete_requested then
    Snacks.notify.warn("Only open buffers can be deleted", { title = "Snacks Picker" })
  end

  local cursor = picker.list.cursor
  picker:find({
    on_done = function()
      picker.list:view(cursor)
    end,
  })
end

function M.git_stage(picker)
  local items = picker:selected({ fallback = true })
  local cursor = picker.list.cursor
  for _, item in ipairs(items) do
    local cmd = item.status:sub(2) == " " and { "git", "restore", "--staged", item.file } or { "git", "add", item.file }
    Snacks.picker.util.cmd(cmd, function(data, code)
      picker:find({
        on_done = function()
          picker.list:view(cursor + 1)
        end,
      })
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
    local what = item.branch or item.commit
    if not what then
      Snacks.notify.warn("No branch or commit found", { title = "Snacks Picker" })
      return
    end
    local cmd = { "git", "checkout", what }
    if item.file then
      vim.list_extend(cmd, { "--", item.file })
    end
    Snacks.picker.util.cmd(cmd, function()
      Snacks.notify("Checkout " .. what, { title = "Snacks Picker" })
      vim.cmd.checktime()
    end, { cwd = item.cwd })
  end
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
      col = item.pos and item.pos[2] or 1,
      end_lnum = item.end_pos and item.end_pos[1] or nil,
      end_col = item.end_pos and item.end_pos[2] or nil,
      text = item.line or item.comment or item.label or item.name or item.detail or item.text,
      pattern = item.search,
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

function M.yank(_, item)
  if item then
    vim.fn.setreg("+", item.data or item.text)
  end
end
M.copy = M.yank

function M.put(picker, item)
  picker:close()
  if item then
    vim.api.nvim_put({ item.data or item.text }, "c", true, true)
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
  M.list_down(picker)
end

--- Toggles the selection of the current item,
--- and moves the cursor to the prev item.
function M.select_and_prev(picker)
  picker.list:select()
  M.list_up(picker)
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
      if item.command and (item.command.nargs ~= "0") then
        vim.api.nvim_input(":" .. item.cmd .. " ")
      else
        vim.cmd(item.cmd)
      end
    end)
  end
end

function M.search(picker, item)
  picker:close()
  if item then
    vim.api.nvim_input("/" .. item.text)
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
    picker.list.win:focus()
  else
    picker.input.win:focus()
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
  picker.input.win:focus()
end

function M.focus_list(picker)
  picker.list.win:focus()
end

function M.focus_preview(picker)
  picker.preview.win:focus()
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
  picker.list:move(1)
end

function M.list_up(picker)
  picker.list:move(-1)
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
