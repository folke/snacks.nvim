---@class snacks.picker.previewers
local M = {}

local uv = vim.uv or vim.loop
local ns = vim.api.nvim_create_namespace("snacks.picker.preview")

---@param ctx snacks.picker.preview.ctx
function M.directory(ctx)
  ctx.preview:reset()
  ctx.preview:minimal()
  local path = Snacks.picker.util.path(ctx.item)
  if not path then
    ctx.preview:notify("Item has no `file`", "error")
    return
  end
  local name = vim.fn.fnamemodify(path, ":t")
  ctx.preview:set_title(ctx.item.title or name)
  local ls = {} ---@type {file:string, type:"file"|"directory"}[]
  for file, t in vim.fs.dir(path) do
    t = t or Snacks.util.path_type(path .. "/" .. file)
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
    local icon, icon_hl = Snacks.util.icon(item.file, cat, {
      fallback = ctx.picker.opts.icons.files,
    })
    local line = { { icon .. " ", icon_hl }, { item.file, hl } }
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
  if ctx.item.buf and not vim.api.nvim_buf_is_valid(ctx.item.buf) and (ctx.item.file or ""):sub(1, 1) == "[" then
    ctx.preview:notify("Buffer no longer exists", "error")
    return
  end

  local title = ctx.item.preview_title or ctx.item.title

  -- used by some LSP servers that load buffers with custom URIs
  if ctx.item.buf and vim.uri_from_bufnr(ctx.item.buf):sub(1, 4) ~= "file" then
    if not vim.api.nvim_buf_is_loaded(ctx.item.buf) then
      vim.b[ctx.item.buf].snacks_picker_loaded = true
      vim.fn.bufload(ctx.item.buf)
    end
  elseif ctx.item.file and ctx.item.file:find("^%w+://") then
    ctx.item.buf = vim.fn.bufadd(ctx.item.file)
    vim.b[ctx.item.buf].snacks_picker_loaded = true
    vim.fn.bufload(ctx.item.buf)
  end

  if ctx.item.buf and vim.api.nvim_buf_is_loaded(ctx.item.buf) then
    if not title then
      local name = vim.api.nvim_buf_get_name(ctx.item.buf)
      title = uv.fs_stat(name) and vim.fn.fnamemodify(name, ":t") or name
    end
    ctx.preview:set_title(title)
    ctx.preview:set_buf(ctx.item.buf)
  else
    local path = Snacks.picker.util.path(ctx.item)
    if not path then
      ctx.preview:notify("Item has no `file`", "error")
      return
    end

    if Snacks.image.supports_file(path) and Snacks.image.config.enabled ~= false then
      return M.image(ctx)
    end

    -- re-use existing preview when path is the same
    if path ~= Snacks.picker.util.path(ctx.prev) then
      ctx.preview:reset()
      vim.bo[ctx.buf].buftype = ""

      title = title or vim.fn.fnamemodify(path, ":t")
      ctx.preview:set_title(title)

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

---@param diff string|string[]|snacks.picker.diff.Block[]
---@param ft "diff"|"git"
---@param ctx snacks.picker.preview.ctx
local function fancy_diff(diff, ft, ctx)
  local buf = ctx.preview:scratch()
  ctx.preview.win:map()
  require("snacks.picker.util.diff").render(buf, ns, diff, {
    annotations = ctx.item.annotations or ctx.picker.opts.annotations,
  })
  Snacks.util.wo(ctx.win, ctx.picker.opts.previewers.diff.wo or {})
end

---@param cmd string[]
---@param ctx snacks.picker.preview.ctx
---@param opts? snacks.job.Opts|{ft?: string}
function M.cmd(cmd, ctx, opts)
  opts = opts or {}
  local Job = require("snacks.util.job")
  local buf = ctx.preview:scratch()
  vim.bo[buf].buftype = "nofile"

  opts = Snacks.config.merge(opts, {
    debug = ctx.picker.opts.debug.proc,
    term = opts.term ~= false and not opts.ft and opts.pty ~= false,
    width = vim.api.nvim_win_get_width(ctx.win),
    height = vim.api.nvim_win_get_height(ctx.win),
    cwd = ctx.item.cwd or ctx.picker.opts.cwd,
    env = {
      PAGER = "cat",
      DELTA_PAGER = "cat",
    },
  })

  local style = ctx.picker.opts.previewers.diff.style
  if style == "fancy" and vim.tbl_contains({ "diff", "git" }, opts.ft) then
    opts.on_line = function() end or nil -- disable default line handler
    opts.on_lines = function(_, lines)
      fancy_diff(lines, opts.ft, ctx)
    end
  end

  local job = Job.new(buf, cmd, opts)

  if opts.ft and style ~= "fancy" then
    ctx.preview:highlight({ ft = opts.ft })
  end
  return job
end

---@param ctx snacks.picker.preview.ctx
---@return string[], boolean terminal
local function git(ctx, ...)
  local terminal = ctx.picker.opts.previewers.diff.style == "terminal"
  local ret = { "git" }
  vim.list_extend(ret, not terminal and { "--no-pager" } or {})
  vim.list_extend(ret, ctx.picker.opts.previewers.git.args or {})
  vim.list_extend(ret, { ... })
  return ret, terminal
end

---@param ctx snacks.picker.preview.ctx
function M.git_show(ctx)
  local cmd, terminal = git(ctx, "show", ctx.item.commit)
  local pathspec = ctx.item.files or ctx.item.file
  pathspec = type(pathspec) == "table" and pathspec or { pathspec }
  if #pathspec > 0 then
    cmd[#cmd + 1] = "--"
    vim.list_extend(cmd, pathspec)
  end
  M.cmd(cmd, ctx, { ft = not terminal and "git" or nil })
end

---@param ctx snacks.picker.preview.ctx
function M.git_log(ctx)
  local cmd = git(
    ctx,
    "--no-pager",
    "log",
    "--pretty=format:%h %s (%ch) <%an>",
    "--abbrev-commit",
    "--decorate",
    "--date=short",
    "--color=never",
    "--no-show-signature",
    "--no-patch",
    ctx.item.commit
  )
  M.cmd(cmd, ctx, {
    ft = "git",
    ---@param text string
    on_line = function(_, text)
      local commit, msg, date, author = text:match("^(%S+) (.*) %((.*)%) <(.*)>$")
      if commit then
        local hl = Snacks.picker.format.git_log({
          idx = 1,
          score = 0,
          text = "",
          commit = commit,
          msg = msg,
          date = date,
          author = author,
        }, ctx.picker)
        Snacks.picker.highlight.render(ctx.buf, ns, { hl }, { append = true })
        Snacks.util.wo(ctx.win, { breakindent = true, wrap = true, linebreak = true })
      end
    end,
  })
end

---@param ctx snacks.picker.preview.ctx
function M.diff(ctx)
  local style = ctx.picker.opts.previewers.diff.style
  local cmd = vim.deepcopy(ctx.picker.opts.previewers.diff.cmd)
  style = style == "terminal" and vim.fn.executable(cmd[1]) == 0 and "fancy" or style
  if style == "syntax" then
    ctx.item.preview = { text = ctx.item.diff, ft = "diff", loc = false }
    return M.preview(ctx)
  elseif style ~= "terminal" then
    return fancy_diff(ctx.item.diff, "diff", ctx)
  end
  if cmd[1] == "delta" and not vim.tbl_contains(cmd, "--dark") and not vim.tbl_contains(cmd, "--light") then
    table.insert(cmd, 2, "--" .. vim.o.background)
  end
  M.cmd(cmd, ctx, {
    input = ctx.item.diff,
  })
end

---@param ctx snacks.picker.preview.ctx
function M.git_diff(ctx)
  local cmd, terminal = git(ctx, "diff")
  if not ctx.item.status then
    cmd[#cmd + 1] = "HEAD" -- generic diff against HEAD
  elseif ctx.item.status:find("[UAD][UAD]") then
    cmd[#cmd + 1] = "--cc" -- combined diff for conflicts
  elseif ctx.item.status:sub(1, 1) ~= " " then
    cmd[#cmd + 1] = "--cached" -- staged changes
  end
  if ctx.item.file then
    vim.list_extend(cmd, { "--", ctx.item.file })
  end
  M.cmd(cmd, ctx, {
    ft = not terminal and "diff" or nil,
  })
end

---@param ctx snacks.picker.preview.ctx
function M.git_stash(ctx)
  local cmd, terminal = git(ctx, "stash", "show", "--patch", ctx.item.stash)
  M.cmd(cmd, ctx, { ft = not terminal and "diff" or nil })
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
