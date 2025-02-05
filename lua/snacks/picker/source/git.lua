local M = {}

local uv = vim.uv or vim.loop

local commit_pat = ("[a-z0-9]"):rep(7)

---@param opts snacks.picker.git.files.Config
---@type snacks.picker.finder
function M.files(opts, ctx)
  local args = { "-c", "core.quotepath=false", "ls-files", "--exclude-standard", "--cached" }
  if opts.untracked then
    table.insert(args, "--others")
  elseif opts.submodules then
    table.insert(args, "--recurse-submodules")
  end
  if not opts.cwd then
    opts.cwd = Snacks.git.get_root() or uv.cwd() or "."
    ctx.picker:set_cwd(opts.cwd)
  end
  local cwd = vim.fs.normalize(opts.cwd) or nil
  return require("snacks.picker.source.proc").proc({
    opts,
    {
      cmd = "git",
      args = args,
      ---@param item snacks.picker.finder.Item
      transform = function(item)
        item.cwd = cwd
        item.file = item.text
      end,
    },
  }, ctx)
end

---@param opts snacks.picker.git.log.Config
---@type snacks.picker.finder
function M.log(opts, ctx)
  local args = {
    "log",
    "--pretty=format:%h %s (%ch)",
    "--abbrev-commit",
    "--decorate",
    "--date=short",
    "--color=never",
    "--no-show-signature",
    "--no-patch",
  }
  if opts.follow and not opts.current_file then
    opts.follow = nil
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

  local cwd = vim.fs.normalize(file and vim.fn.fnamemodify(file, ":h") or opts and opts.cwd or uv.cwd() or ".") or nil
  return require("snacks.picker.source.proc").proc({
    opts,
    {
      cwd = cwd,
      cmd = "git",
      args = args,
      ---@param item snacks.picker.finder.Item
      transform = function(item)
        local commit, msg, date = item.text:match("^(%S+) (.*) %((.*)%)$")
        if not commit then
          error(item.text)
        end
        item.cwd = cwd
        item.commit = commit
        item.msg = msg
        item.date = date
        item.file = file
      end,
    },
  }, ctx)
end

---@param opts snacks.picker.git.status.Config
---@type snacks.picker.finder
function M.status(opts, ctx)
  local args = {
    "--no-pager",
    "status",
    "-uall",
    "--porcelain=v1",
    "-z",
  }
  if opts.ignored then
    table.insert(args, "--ignored=matching")
  end

  local cwd = vim.fs.normalize(opts and opts.cwd or uv.cwd() or ".") or nil
  cwd = Snacks.git.get_root(cwd)
  return require("snacks.picker.source.proc").proc({
    opts,
    {
      sep = "\0",
      cwd = cwd,
      cmd = "git",
      args = args,
      ---@param item snacks.picker.finder.Item
      transform = function(item)
        local status, file = item.text:sub(1, 2), item.text:sub(4)
        item.cwd = cwd
        item.status = status
        item.file = file
      end,
    },
  }, ctx)
end

---@param opts snacks.picker.Config
---@type snacks.picker.finder
function M.diff(opts, ctx)
  local args = { "--no-pager", "diff", "--no-color", "--no-ext-diff" }
  local file, line ---@type string?, number?
  local header, hunk = {}, {} ---@type string[], string[]
  local finder = require("snacks.picker.source.proc").proc({
    opts,
    { cmd = "git", args = args },
  }, ctx)
  return function(cb)
    local function add()
      if file and line and #hunk > 0 then
        local diff = table.concat(header, "\n") .. "\n" .. table.concat(hunk, "\n")
        cb({
          text = file .. ":" .. line,
          file = file,
          pos = { line, 0 },
          preview = { text = diff, ft = "diff", loc = false },
        })
      end
      hunk = {}
    end
    finder(function(proc_item)
      local text = proc_item.text
      if text:find("diff", 1, true) == 1 then
        add()
        file = text:match("^diff .* a/(.*) b/.*$")
        header = { text }
      elseif file and #header < 4 then
        header[#header + 1] = text
      elseif text:find("@", 1, true) == 1 then
        add()
        -- Hunk header
        -- @example "@@ -157,20 +157,6 @@ some content"
        line = tonumber(string.match(text, "@@ %-.*,.* %+(.*),.* @@"))
        hunk = { text }
      elseif #hunk > 0 then
        hunk[#hunk + 1] = text
      else
        error("unexpected line: " .. text)
      end
    end)
    add()
  end
end

---@param opts snacks.picker.Config
---@type snacks.picker.finder
function M.branches(opts, ctx)
  local args = { "--no-pager", "branch", "--no-color", "-vvl" }
  local cwd = vim.fs.normalize(opts and opts.cwd or uv.cwd() or ".") or nil
  cwd = Snacks.git.get_root(cwd)

  local patterns = {
    -- stylua: ignore start
    --- e.g. "* (HEAD detached at f65a2c8) f65a2c8 chore(build): auto-generate docs"
    "^(.)%s(%b())%s+(" .. commit_pat .. ")%s*(.*)$",
    --- e.g. "  main                       d2b2b7b [origin/main: behind 276] chore(build): auto-generate docs"
    "^(.)%s(%S+)%s+(".. commit_pat .. ")%s*(.*)$",
    -- stylua: ignore end
  } ---@type string[]

  return require("snacks.picker.source.proc").proc({
    opts,
    {
      cwd = cwd,
      cmd = "git",
      args = args,
      ---@param item snacks.picker.finder.Item
      transform = function(item)
        item.cwd = cwd
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
    },
  }, ctx)
end

---@param opts snacks.picker.Config
---@type snacks.picker.finder
function M.stash(opts, ctx)
  local args = { "--no-pager", "stash", "list" }
  local cwd = vim.fs.normalize(opts and opts.cwd or uv.cwd() or ".") or nil
  cwd = Snacks.git.get_root(cwd)

  return require("snacks.picker.source.proc").proc({
    opts,
    {
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
    },
  }, ctx)
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
