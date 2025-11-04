local M = {}

local uv = vim.uv or vim.loop

local commit_pat = ("[a-z0-9]"):rep(7)

---@class snacks.picker.git.Args
---@field args? string[] additional arguments to pass to `git`
---@field cmd_args? string[] additional arguments to pass to the `git <cmd>``

---@param cmd string
---@param ... string|snacks.picker.git.Args
function M.git(cmd, ...)
  local args, cmd_args = {}, {} ---@type string[], string[]

  for i = 1, select("#", ...) do
    local arg = select(i, ...)
    if type(arg) == "string" then
      cmd_args[#cmd_args + 1] = arg
    else
      vim.list_extend(args, arg.args or {})
      vim.list_extend(cmd_args, arg.cmd_args or {})
    end
  end

  local ret = { "-c", "core.quotepath=false" } ---@type string[]
  vim.list_extend(ret, args)
  ret[#ret + 1] = cmd
  vim.list_extend(ret, cmd_args)
  return ret
end

---@param opts snacks.picker.git.files.Config
---@type snacks.picker.finder
function M.files(opts, ctx)
  local args = M.git("ls-files", "--exclude-standard", "--cached", opts)
  if opts.untracked then
    table.insert(args, "--others")
  elseif opts.submodules then
    table.insert(args, "--recurse-submodules")
  end
  if not opts.cwd then
    opts.cwd = ctx:git_root()
    ctx.picker:set_cwd(opts.cwd)
  end
  local cwd = svim.fs.normalize(opts.cwd) or nil
  return require("snacks.picker.source.proc").proc(
    ctx:opts({
      cmd = "git",
      args = args,
      ---@param item snacks.picker.finder.Item
      transform = function(item)
        item.cwd = cwd
        item.file = item.text
      end,
    }),
    ctx
  )
end

---@param opts snacks.picker.git.grep.Config
---@type snacks.picker.finder
function M.grep(opts, ctx)
  if opts.need_search ~= false and ctx.filter.search == "" then
    return function() end
  end
  local args = M.git("grep", "--line-number", "--column", "--no-color", "-I", opts)
  if opts.untracked then
    table.insert(args, "--untracked")
  elseif opts.submodules then
    table.insert(args, "--recurse-submodules")
  end
  if opts.ignorecase then
    table.insert(args, "-i")
  end

  local pattern, pargs = Snacks.picker.util.parse(ctx.filter.search)
  table.insert(args, pattern)

  args[#args + 1] = "--"
  vim.list_extend(args, pargs)

  local pathspec = type(opts.pathspec) == "table" and opts.pathspec or { opts.pathspec }
  ---@cast pathspec string[]
  vim.list_extend(args, pathspec)

  if not opts.cwd then
    opts.cwd = ctx:git_root()
    ctx.picker:set_cwd(opts.cwd)
  end
  local cwd = svim.fs.normalize(opts.cwd) or nil
  return require("snacks.picker.source.proc").proc(
    ctx:opts({
      cmd = "git",
      args = args,
      notify = false,
      ---@param item snacks.picker.finder.Item
      transform = function(item)
        item.cwd = cwd
        local file, line, col, text = item.text:match("^(.+):(%d+):(%d+):(.*)$")
        if not file then
          if not item.text:match("WARNING") then
            Snacks.notify.error("invalid grep output:\n" .. item.text)
          end
          return false
        else
          item.line = text
          item.file = file
          item.pos = { tonumber(line), tonumber(col) - 1 }
        end
      end,
    }),
    ctx
  )
end

---@param opts snacks.picker.git.log.Config
---@type snacks.picker.finder
function M.log(opts, ctx)
  local args = M.git(
    "log",
    "--pretty=format:%h %s (%ch) <%an>",
    "--abbrev-commit",
    "--decorate",
    "--date=short",
    "--color=never",
    "--no-show-signature",
    "--no-patch",
    opts
  )

  if opts.author then
    table.insert(args, "--author=" .. opts.author)
  end

  local file ---@type string?
  if opts.current_line then
    local cursor = vim.api.nvim_win_get_cursor(ctx.filter.current_win)
    file = vim.api.nvim_buf_get_name(ctx.filter.current_buf)
    local line = cursor[1]
    args[#args + 1] = "-L"
    args[#args + 1] = line .. ",+1:" .. file
  elseif opts.current_file then
    file = vim.api.nvim_buf_get_name(ctx.filter.current_buf)
    if opts.follow then
      args[#args + 1] = "--follow"
    end
    args[#args + 1] = "--"
    args[#args + 1] = file
  end

  if ctx.filter.search ~= "" then
    vim.list_extend(args, { "-S", ctx.filter.search })
  end

  local Proc = require("snacks.picker.source.proc")
  file = file and svim.fs.normalize(file) or nil

  local cwd = svim.fs.normalize(file and vim.fn.fnamemodify(file, ":h") or opts and opts.cwd or uv.cwd() or ".") or nil
  cwd = Snacks.git.get_root(cwd) or cwd

  local renames = { file } ---@type string[]
  return function(cb)
    if file then
      -- detect renames
      local is_rename = false
      Proc.proc({
        cmd = "git",
        cwd = cwd,
        args = M.git(
          "log",
          "-z",
          "--follow",
          "--name-status",
          "--pretty=format:''",
          "--diff-filter=R",
          "--",
          file,
          opts
        ),
      }, ctx)(function(item)
        for _, text in ipairs(vim.split(item.text, "\0")) do
          if text:find("^R%d%d%d$") then
            is_rename = true
          elseif is_rename then
            is_rename = false
            renames[#renames + 1] = text
          end
        end
      end)
    end

    Proc.proc(
      ctx:opts({
        cwd = cwd,
        cmd = "git",
        args = args,
        ---@param item snacks.picker.finder.Item
        transform = function(item)
          local commit, msg, date, author = item.text:match("^(%S+) (.*) %((.*)%) <(.*)>$")
          if not commit then
            Snacks.notify.error(("failed to parse log item:\n%q"):format(item.text))
            return false
          end
          item.cwd = cwd
          item.commit = commit
          item.msg = msg
          item.date = date
          item.author = author
          item.file = file
          item.files = renames
        end,
      }),
      ctx
    )(cb)
  end
end

---@param opts snacks.picker.git.status.Config
---@type snacks.picker.finder
function M.status(opts, ctx)
  local args = M.git("status", "-uall", "--porcelain=v1", "-z", { args = { "--no-pager" } }, opts)
  if opts.ignored then
    table.insert(args, "--ignored=matching")
  end

  local cwd = ctx:git_root()
  local prev ---@type snacks.picker.finder.Item?
  return require("snacks.picker.source.proc").proc(
    ctx:opts({
      sep = "\0",
      cwd = cwd,
      cmd = "git",
      args = args,
      ---@param item snacks.picker.finder.Item
      transform = function(item)
        local status, file = item.text:match("^(..) (.+)$")
        if status then
          item.cwd = cwd
          item.status = status
          item.file = file
          prev = item
        elseif prev and prev.status:find("R") then
          prev.rename = item.text
          return false
        else
          return false
        end
      end,
    }),
    ctx
  )
end

---@param opts snacks.picker.git.diff.Config
---@type snacks.picker.finder
function M.diff(opts, ctx)
  opts = opts or {}
  local args = M.git("diff", "--no-color", "--no-ext-diff", "--diff-filter=u", { args = { "--no-pager" } }, opts)
  if opts.base then
    vim.list_extend(args, { "--merge-base", opts.base })
  end
  if opts.staged then
    table.insert(args, "--cached")
  end

  local Diff = require("snacks.picker.source.diff")
  local finders = {} ---@type snacks.picker.finder.result[]
  finders[#finders + 1] = Diff.diff(
    ctx:opts({
      cmd = "git",
      args = args,
      cwd = ctx:git_root(),
    }),
    ctx
  )
  if opts.staged == nil and opts.base == nil then
    finders[#finders + 1] = Diff.diff(
      ctx:opts({
        cmd = "git",
        args = vim.list_extend(vim.deepcopy(args), { "--cached" }),
        cwd = ctx:git_root(),
      }),
      ctx
    )
  end
  return function(cb)
    local items = {} ---@type snacks.picker.finder.Item[]
    for f, finder in ipairs(finders) do
      finder(function(item)
        if not opts.base then
          item.staged = opts.staged or f == 2
        end
        items[#items + 1] = item
      end)
    end
    table.sort(items, function(a, b)
      if a.file ~= b.file then
        return a.file < b.file
      end
      return a.pos[1] < b.pos[1]
    end)
    for _, item in ipairs(items) do
      cb(item)
    end
  end
end

---@param opts snacks.picker.git.branches.Config
---@type snacks.picker.finder
function M.branches(opts, ctx)
  local args = M.git("branch", "--no-color", "-vvl", { args = { "--no-pager" } }, opts)
  if opts.all then
    table.insert(args, "--all")
  end
  local cwd = ctx:git_root()

  local patterns = {
    -- stylua: ignore start
    --- e.g. "* (HEAD detached at f65a2c8) f65a2c8 chore(build): auto-generate docs"
    "^(.)%s(%b())%s+(" .. commit_pat .. ")%s*(.*)$",
    --- e.g. "  main                       d2b2b7b [origin/main: behind 276] chore(build): auto-generate docs"
    "^(.)%s(%S+)%s+(".. commit_pat .. ")%s*(.*)$",
    -- stylua: ignore end
  } ---@type string[]

  return require("snacks.picker.source.proc").proc(
    ctx:opts({
      cwd = cwd,
      cmd = "git",
      args = args,
      ---@param item snacks.picker.finder.Item
      transform = function(item)
        item.cwd = cwd
        if item.text:find("HEAD.*%->") then
          return false
        end
        for p, pattern in ipairs(patterns) do
          local status, branch, commit, msg = item.text:match(pattern)
          if status then
            local detached = p == 1
            item.current = status == "*"
            item.branch = not detached and branch or nil
            item.commit = commit
            item.msg = msg
            item.detached = detached
            return
          end
        end
        Snacks.notify.warn("failed to parse branch: " .. item.text)
        return false -- skip items we could not parse
      end,
    }),
    ctx
  )
end

---@param opts snacks.picker.git.Config
---@type snacks.picker.finder
function M.stash(opts, ctx)
  local args = M.git("stash", "list", { args = { "--no-pager" } }, opts)
  local cwd = ctx:git_root()

  return require("snacks.picker.source.proc").proc(
    ctx:opts({
      cwd = cwd,
      cmd = "git",
      args = args,
      ---@param item snacks.picker.finder.Item
      transform = function(item)
        if item.text:find("autostash", 1, true) then
          return false
        end
        local stash, branch, msg = item.text:gsub(": On (%S+):", ": WIP on %1:"):match("^(%S+): WIP on (%S+): (.*)$")
        if stash then
          local commit, m = msg:match("^(" .. commit_pat .. ") (.*)")
          item.cwd = cwd
          item.stash = stash
          item.branch = branch
          item.commit = commit
          item.msg = m or msg
          return
        end
        Snacks.notify.warn("failed to parse stash:\n```git\n" .. item.text .. "\n```")
        return false -- skip items we could not parse
      end,
    }),
    ctx
  )
end

---@class snacks.picker.git.Status
---@field xy string
---@field status "modified" | "deleted" | "added" | "untracked" | "renamed" | "copied" | "ignored"
---@field unmerged? boolean
---@field staged? boolean
---@field priority? number

---@param xy string
---@return snacks.picker.git.Status
function M.git_status(xy)
  local ss = {
    A = "added",
    D = "deleted",
    M = "modified",
    R = "renamed",
    C = "copied",
    ["?"] = "untracked",
    ["!"] = "ignored",
  }
  local prios = "!?CRDAM"

  ---@param status string
  ---@param unmerged? boolean
  ---@param staged? boolean
  local function s(status, unmerged, staged)
    local prio = (prios:find(status, 1, true) or 0) + (unmerged and 20 or 0)
    if not staged and not status:find("[!]") then
      prio = prio + 10
    end
    return {
      xy = xy,
      status = ss[status],
      unmerged = unmerged,
      staged = staged,
      priority = prio,
    }
  end
  ---@param c string
  local function f(c)
    return xy:gsub("T", "M"):match(c) --[[@as string?]]
  end

  if f("%?%?") then
    return s("?")
  elseif f("!!") then
    return s("!")
  elseif f("UU") then
    return s("M", true)
  elseif f("DD") then
    return s("D", true)
  elseif f("AA") then
    return s("A", true)
  elseif f("U") then
    return s(f("A") and "A" or "D", true)
  end

  local m = f("^([MADRC])")
  if m then
    return s(m, nil, true)
  end
  m = f("([MADRC])$")
  if m then
    return s(m)
  end
  error("unknown status: " .. xy)
end

---@param a string
---@param b string
function M.merge_status(a, b)
  if a == b then
    return a
  end
  local as = M.git_status(a)
  local bs = M.git_status(b)
  if as.unmerged or bs.unmerged then
    return as.priority > bs.priority and as.xy or bs.xy
  end
  if not as.staged or not bs.staged then
    if as.status == bs.status then
      return as.staged and b or a
    end
    return " M"
  end
  return "M "
end

return M
