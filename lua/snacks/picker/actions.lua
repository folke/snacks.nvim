---@class snacks.picker.actions
---@field [string] snacks.picker.Action.spec
local M = {}

local SCROLL_WHEEL_DOWN = Snacks.util.keycode("<ScrollWheelDown>")
local SCROLL_WHEEL_UP = Snacks.util.keycode("<ScrollWheelUp>")

---@class snacks.picker.jump.Action: snacks.picker.Action
---@field cmd? string

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

  picker:close()

  if action.cmd then
    vim.cmd(action.cmd)
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

  local items = picker:selected({ fallback = true })

  for _, item in ipairs(items) do
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

    if not vim.api.nvim_buf_is_loaded(buf) then
      vim.cmd("buffer " .. buf)
      vim.bo[buf].buflisted = true
    end

    -- set the buffer
    vim.api.nvim_win_set_buf(win, buf)

    -- set the cursor
    if item.pos then
      vim.api.nvim_win_set_cursor(win, { item.pos[1], item.pos[2] })
    elseif item.search then
      vim.cmd(item.search)
      vim.cmd("noh")
    end
    -- center
    vim.cmd("norm! zzzv")
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

M.cancel = "close"
M.edit = M.jump
M.confirm = M.jump
M.edit_split = { action = "jump", cmd = "split" }
M.edit_vsplit = { action = "jump", cmd = "vsplit" }
M.edit_tab = { action = "jump", cmd = "tabnew" }

function M.toggle_maximize(picker)
  picker.layout:maximize()
end

function M.toggle_preview(picker)
  picker.layout:toggle("preview")
  picker:show_preview()
end

function M.bufdelete(picker)
  for _, item in ipairs(picker:selected({ fallback = true })) do
    Snacks.bufdelete.delete(item.buf)
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
    vim.cmd("lopen")
  else
    vim.fn.setqflist(qf)
    vim.cmd("copen")
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

function M.copy(_, item)
  if item then
    vim.fn.setreg("+", item.data or item.text)
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
      vim.cmd(item.cmd)
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
function M.load_session(picker)
  picker:close()
  local item = picker:current()
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

function M.help(picker)
  local item = picker:current()
  if item then
    picker:close()
    vim.cmd("help " .. item.text)
  end
end

function M.preview_scroll_down(picker)
  picker.preview.win:scroll()
end

function M.preview_scroll_up(picker)
  picker.preview.win:scroll(true)
end

function M.inspect(picker, item)
  Snacks.debug.inspect(item)
end

function M.toggle_live(picker)
  if not picker.opts.supports_live then
    Snacks.notify.warn("Live search is not supported for `" .. picker.source_name .. "`", { title = "Snacks Picker" })
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
  if win == picker.input.win.win then
    vim.cmd("startinsert")
  end
end

function M.focus_input(picker)
  picker.input.win:focus()
  vim.cmd("startinsert")
end

function M.focus_list(picker)
  picker.list.win:focus()
end

function M.focus_preview(picker)
  picker.preview.win:focus()
end

function M.toggle_ignored(picker)
  local opts = picker.opts --[[@as snacks.picker.files.Config]]
  opts.ignored = not opts.ignored
  picker:find()
end

function M.toggle_hidden(picker)
  local opts = picker.opts --[[@as snacks.picker.files.Config]]
  opts.hidden = not opts.hidden
  picker:find()
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

function M.list_scroll_wheel_down(picker)
  local mouse_win = vim.fn.getmousepos().winid
  if mouse_win == picker.list.win.win then
    picker.list:scroll(picker.list.state.mousescroll)
  else
    vim.api.nvim_feedkeys(SCROLL_WHEEL_DOWN, "n", true)
  end
end

function M.list_scroll_wheel_up(picker)
  local mouse_win = vim.fn.getmousepos().winid
  if mouse_win == picker.list.win.win then
    picker.list:scroll(-picker.list.state.mousescroll)
  else
    vim.api.nvim_feedkeys(SCROLL_WHEEL_UP, "n", true)
  end
end

return M
