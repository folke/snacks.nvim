---@class snacks.picker.previewers
local M = {}

local uv = vim.uv or vim.loop
local ns = vim.api.nvim_create_namespace("snacks.picker.preview")

---@param ctx snacks.picker.preview.ctx
function M.directory(ctx)
  ctx.preview:reset()
  ctx.preview:minimal()
  local path = Snacks.picker.util.path(ctx.item)
  local name = path and vim.fn.fnamemodify(path, ":t")
  ctx.preview:set_title(ctx.item.title or name)
  local ls = {} ---@type {file:string, type:"file"|"directory"}[]
  for file, t in vim.fs.dir(ctx.item.file) do
    t = t or Snacks.util.path_type(ctx.item.file .. "/" .. file)
    ls[#ls + 1] = { file = file, type = t }
  end
  ctx.preview:set_lines(vim.split(string.rep("\n", #ls), "\n"))
  table.sort(ls, function(a, b)
    if a.type ~= b.type then
      return a.type == "directory"
    end
    return a.file < b.file
  end)
  for i, item in ipairs(ls) do
    local is_dir = item.type == "directory"
    local cat = is_dir and "directory" or "file"
    local hl = is_dir and "Directory" or nil
    local path = item.file
    local icon, icon_hl = Snacks.util.icon(path, cat, {
      fallback = ctx.picker.opts.icons.files,
    })
    local line = { { icon .. " ", icon_hl }, { path, hl } }
    vim.api.nvim_buf_set_extmark(ctx.buf, ns, i - 1, 0, {
      virt_text = line,
    })
  end
end

---@param ctx snacks.picker.preview.ctx
function M.image(ctx)
  local buf = ctx.preview:scratch()
  ctx.preview:set_title(ctx.item.title or vim.fn.fnamemodify(ctx.item.file, ":t"))
  Snacks.image.buf.attach(buf, { src = Snacks.picker.util.path(ctx.item) })
end

---@param ctx snacks.picker.preview.ctx
function M.none(ctx)
  ctx.preview:reset()
  ctx.preview:notify("no preview available", "warn")
end

---@param ctx snacks.picker.preview.ctx
function M.preview(ctx)
  if ctx.item.preview == "file" then
    return M.file(ctx)
  end
  assert(type(ctx.item.preview) == "table", "item.preview must be a table")
  ctx.preview:reset()
  local lines = vim.split(ctx.item.preview.text, "\n")
  ctx.preview:set_lines(lines)
  if ctx.item.preview.ft then
    ctx.preview:highlight({ ft = ctx.item.preview.ft })
  end
  for _, extmark in ipairs(ctx.item.preview.extmarks or {}) do
    local e = vim.deepcopy(extmark)
    e.col, e.row = nil, nil
    vim.api.nvim_buf_set_extmark(ctx.buf, ns, (extmark.row or 1) - 1, extmark.col, e)
  end
  if ctx.item.preview.loc ~= false then
    ctx.preview:loc()
  end
end

---@param ctx snacks.picker.preview.ctx
function M.file(ctx)
  if ctx.item.buf and not ctx.item.file and not vim.api.nvim_buf_is_valid(ctx.item.buf) then
    ctx.preview:notify("Buffer no longer exists", "error")
    return
  end

  -- used by some LSP servers that load buffers with custom URIs
  if ctx.item.buf and vim.uri_from_bufnr(ctx.item.buf):sub(1, 4) ~= "file" then
    vim.fn.bufload(ctx.item.buf)
  elseif ctx.item.file and ctx.item.file:find("^%w+://") then
    ctx.item.buf = vim.fn.bufadd(ctx.item.file)
    vim.fn.bufload(ctx.item.buf)
  end

  if ctx.item.buf and vim.api.nvim_buf_is_loaded(ctx.item.buf) then
    local name = vim.api.nvim_buf_get_name(ctx.item.buf)
    name = uv.fs_stat(name) and vim.fn.fnamemodify(name, ":t") or name
    ctx.preview:set_title(name)
    ctx.preview:set_buf(ctx.item.buf)
  else
    local path = Snacks.picker.util.path(ctx.item)
    if not path then
      ctx.preview:notify("Item has no `file`", "error")
      return
    end

    if Snacks.image.supports_file(path) then
      return M.image(ctx)
    end

    -- re-use existing preview when path is the same
    if path ~= Snacks.picker.util.path(ctx.prev) then
      ctx.preview:reset()
      vim.bo[ctx.buf].buftype = ""

      local name = vim.fn.fnamemodify(path, ":t")
      ctx.preview:set_title(ctx.item.title or name)

      local stat = uv.fs_stat(path)
      if not stat then
        ctx.preview:notify("file not found: " .. path, "error")
        return false
      end
      if stat.type == "directory" then
        return M.directory(ctx)
      end
      local max_size = ctx.picker.opts.previewers.file.max_size or (1024 * 1024)
      if stat.size > max_size then
        ctx.preview:notify("large file > 1MB", "warn")
        return false
      end
      if stat.size == 0 then
        ctx.preview:notify("empty file", "warn")
        return false
      end

      local file = assert(io.open(path, "r"))

      local is_binary = false
      local ft = ctx.picker.opts.previewers.file.ft or vim.filetype.match({ filename = path })
      if ft == "bigfile" then
        ft = nil
      end
      local lines = {}
      for line in file:lines() do
        ---@cast line string
        if #line > ctx.picker.opts.previewers.file.max_line_length then
          line = line:sub(1, ctx.picker.opts.previewers.file.max_line_length) .. "..."
        end
        -- Check for binary data in the current line
        if line:find("[%z\1-\8\11\12\14-\31]") then
          is_binary = true
          if not ft then
            ctx.preview:notify("binary file", "warn")
            return
          end
        end
        table.insert(lines, line)
      end

      file:close()

      if is_binary then
        ctx.preview:wo({ number = false, relativenumber = false, cursorline = false, signcolumn = "no" })
      end
      ctx.preview:set_lines(lines)
      ctx.preview:highlight({ file = path, ft = ctx.picker.opts.previewers.file.ft, buf = ctx.buf })
    end
  end
  ctx.preview:loc()
end

---@param cmd string[]
---@param ctx snacks.picker.preview.ctx
---@param opts? {add?:fun(text:string, row:number), env?:table<string, string>, pty?:boolean, ft?:string, input?:string}
function M.cmd(cmd, ctx, opts)
  opts = opts or {}
  local buf = ctx.preview:scratch()
  vim.bo[buf].buftype = "nofile"
  local pty = opts.pty ~= false and not opts.ft
  local killed = false
  local chan = pty and vim.api.nvim_open_term(buf, {}) or nil
  local output = {} ---@type string[]
  local line ---@type string?
  local l = 0

  if ctx.picker.opts.debug.proc then
    local args = vim.deepcopy(cmd)
    table.remove(args, 1)
    vim.schedule(function()
      Snacks.debug.cmd({ cmd = cmd[1], args = args, cwd = ctx.item.cwd, group = true })
    end)
  end

  ---@param text string
  local function add_line(text)
    l = l + 1
    vim.bo[buf].modifiable = true
    if opts.add then
      opts.add(text, l)
    else
      vim.api.nvim_buf_set_lines(buf, l - 1, l, false, { text })
    end
    vim.bo[buf].modifiable = false
  end

  ---@param data string
  local function add(data)
    output[#output + 1] = data
    if chan then
      if pcall(vim.api.nvim_chan_send, chan, data) then
        vim.api.nvim_buf_call(buf, function()
          vim.cmd("norm! gg")
        end)
      end
    else
      line = (line or "") .. data
      local lines = vim.split(line, "\r?\n")
      line = table.remove(lines)
      for _, text in ipairs(lines) do
        add_line(text)
      end
    end
  end

  local jid = vim.fn.jobstart(cmd, {
    height = pty and vim.api.nvim_win_get_height(ctx.win) or nil,
    width = pty and vim.api.nvim_win_get_width(ctx.win) or nil,
    -- a bit weird, but we need to set `pty` to `nil` when `opts.input` is set
    -- otherwise the job never receives the input.
    -- Probably won't work with all commands
    pty = not opts.input and pty or nil,
    cwd = ctx.item.cwd or ctx.picker.opts.cwd,
    env = vim.tbl_extend("force", {
      PAGER = "cat",
      DELTA_PAGER = "cat",
    }, opts.env or {}),
    on_stdout = function(_, data)
      if not vim.api.nvim_buf_is_valid(buf) then
        return
      end
      add(table.concat(data, "\n"))
    end,
    on_exit = function(_, code)
      if not killed and line and line ~= "" and vim.api.nvim_buf_is_valid(buf) then
        add_line(line)
      end
      if not killed and code ~= 0 then
        Snacks.notify.error(
          ("Terminal **cmd** `%s` failed with code `%d`:\n- `vim.o.shell = %q`\n\nOutput:\n%s"):format(
            type(cmd) == "table" and table.concat(cmd, " ") or cmd,
            code,
            vim.o.shell,
            vim.trim(table.concat(output, ""))
          )
        )
      end
    end,
    sync = true,
  })
  if jid <= 0 then
    Snacks.notify.error(("Failed to start terminal **cmd** `%s`"):format(cmd))
    if chan then
      vim.fn.chanclose(chan)
    end
    return
  end

  if opts.input then
    vim.fn.chansend(jid, opts.input .. "\n")
    vim.fn.chanclose(jid, "stdin")
  end
  if opts.ft then
    ctx.preview:highlight({ ft = opts.ft })
  end
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    callback = function()
      killed = true
      vim.fn.jobstop(jid)
      if chan then
        vim.fn.chanclose(chan)
      end
    end,
  })
  return jid
end

---@param ctx snacks.picker.preview.ctx
function M.git_show(ctx)
  local builtin = ctx.picker.opts.previewers.git.builtin
  local cmd = {
    "git",
    "-c",
    "delta." .. vim.o.background .. "=true",
    "show",
    ctx.item.commit,
  }
  local pathspec = ctx.item.files or ctx.item.file
  pathspec = type(pathspec) == "table" and pathspec or { pathspec }
  if #pathspec > 0 then
    cmd[#cmd + 1] = "--"
    vim.list_extend(cmd, pathspec)
  end
  if builtin then
    table.insert(cmd, 2, "--no-pager")
  end
  M.cmd(cmd, ctx, { ft = builtin and "git" or nil })
end

---@param ctx snacks.picker.preview.ctx
local function git(ctx, ...)
  local ret = { "git", "-c", "delta." .. vim.o.background .. "=true" }
  vim.list_extend(ret, ctx.picker.opts.previewers.git.args or {})
  vim.list_extend(ret, { ... })
  return ret
end

---@param ctx snacks.picker.preview.ctx
function M.git_log(ctx)
  local cmd = git(
    ctx,
    "--no-pager",
    "log",
    "--pretty=format:%h %s (%ch)",
    "--abbrev-commit",
    "--decorate",
    "--date=short",
    "--color=never",
    "--no-show-signature",
    "--no-patch",
    ctx.item.commit
  )
  local row = 0
  M.cmd(cmd, ctx, {
    ft = "git",
    ---@param text string
    add = function(text)
      local commit, msg, date = text:match("^(%S+) (.*) %((.*)%)$")
      if commit then
        row = row + 1
        local hl = Snacks.picker.format.git_log({
          idx = 1,
          score = 0,
          text = "",
          commit = commit,
          msg = msg,
          date = date,
        }, ctx.picker)
        Snacks.picker.highlight.set(ctx.buf, ns, row, hl)
      end
    end,
  })
end

---@param ctx snacks.picker.preview.ctx
function M.diff(ctx)
  local builtin = ctx.picker.opts.previewers.diff.builtin
  if builtin then
    ctx.item.preview = { text = ctx.item.diff, ft = "diff" }
    return M.preview(ctx)
  end
  local cmd = vim.deepcopy(ctx.picker.opts.previewers.diff.cmd)
  if cmd[1] == "delta" then
    table.insert(cmd, 2, "--" .. vim.o.background)
  end
  M.cmd(cmd, ctx, {
    pty = true,
    input = ctx.item.diff,
  })
end

---@param ctx snacks.picker.preview.ctx
function M.git_diff(ctx)
  local builtin = ctx.picker.opts.previewers.git.builtin
  local cmd = git(ctx, "diff", "HEAD")
  if ctx.item.file then
    vim.list_extend(cmd, { "--", ctx.item.file })
  end
  if builtin then
    table.insert(cmd, 2, "--no-pager")
  end
  M.cmd(cmd, ctx, { ft = builtin and "diff" or nil })
end

---@param ctx snacks.picker.preview.ctx
function M.git_stash(ctx)
  local builtin = ctx.picker.opts.previewers.git.builtin
  local cmd = git(ctx, "stash", "show", "--patch", ctx.item.stash)
  if builtin then
    table.insert(cmd, 2, "--no-pager")
  end
  M.cmd(cmd, ctx, { ft = builtin and "diff" or nil })
end

---@param ctx snacks.picker.preview.ctx
function M.git_status(ctx)
  local ss = ctx.item.status
  if ss:find("^[A?]") then
    M.file(ctx)
  else
    M.git_diff(ctx)
  end
end

---@param ctx snacks.picker.preview.ctx
function M.colorscheme(ctx)
  if not ctx.preview.state.colorscheme then
    ctx.preview.state.colorscheme = vim.g.colors_name or "default"
    ctx.preview.state.background = vim.o.background
    ctx.preview.win:on("WinClosed", function()
      vim.schedule(function()
        if not ctx.preview.state.colorscheme then
          return
        end
        vim.cmd("colorscheme " .. ctx.preview.state.colorscheme)
        vim.o.background = ctx.preview.state.background
      end)
    end, { win = true })
  end
  vim.schedule(function()
    vim.cmd("colorscheme " .. ctx.item.text)
  end)
  Snacks.picker.preview.file(ctx)
end

---@param ctx snacks.picker.preview.ctx
function M.man(ctx)
  M.cmd({ "man", ctx.item.section, ctx.item.page }, ctx, {
    ft = "man",
    env = {
      MANPAGER = ctx.picker.opts.previewers.man_pager or vim.fn.executable("col") == 1 and "col -bx" or "cat",
      MANWIDTH = tostring(ctx.preview.win:dim().width),
      MANPATH = vim.env.MANPATH,
    },
  })
end

return M
