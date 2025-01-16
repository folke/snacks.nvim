local M = {}

local uv = vim.uv or vim.loop

---@class snacks.picker
---@field git_files fun(opts?: snacks.picker.git.files.Config): snacks.Picker
---@field git_log fun(opts?: snacks.picker.git.log.Config): snacks.Picker
---@field git_log_file fun(opts?: snacks.picker.git.log.Config): snacks.Picker
---@field git_log_line fun(opts?: snacks.picker.git.log.Config): snacks.Picker
---@field git_status fun(opts?: snacks.picker.Config): snacks.Picker

---@param opts snacks.picker.git.files.Config
---@type snacks.picker.finder
function M.files(opts)
  local args = { "-c", "core.quotepath=false", "ls-files", "--exclude-standard", "--cached" }
  if opts.untracked then
    table.insert(args, "--others")
  elseif opts.submodules then
    table.insert(args, "--recurse-submodules")
  end
  local cwd = vim.fs.normalize(opts and opts.cwd or uv.cwd() or ".") or nil
  return require("snacks.picker.source.proc").proc(vim.tbl_deep_extend("force", {
    cmd = "git",
    args = args,
    ---@param item snacks.picker.finder.Item
    transform = function(item)
      item.cwd = cwd
      item.file = item.text
    end,
  }, opts or {}))
end

---@param opts snacks.picker.git.log.Config
---@type snacks.picker.finder
function M.log(opts)
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

  if opts.follow and not opts.current_line then
    args[#args + 1] = "--follow"
  end

  if opts.current_line then
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line = cursor[1]
    args[#args + 1] = "-L"
    args[#args + 1] = line .. ",+1:" .. vim.api.nvim_buf_get_name(0)
  elseif opts.current_file then
    args[#args + 1] = "--"
    args[#args + 1] = vim.api.nvim_buf_get_name(0)
  end

  local cwd = vim.fs.normalize(opts and opts.cwd or uv.cwd() or ".") or nil
  return require("snacks.picker.source.proc").proc(vim.tbl_deep_extend("force", {
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
      item.file = item.text
    end,
  }, opts or {}))
end

---@param opts snacks.picker.Config
---@type snacks.picker.finder
function M.status(opts)
  local args = {
    "status",
    "--porcelain=v1",
  }

  local cwd = vim.fs.normalize(opts and opts.cwd or uv.cwd() or ".") or nil
  cwd = Snacks.git.get_root(cwd)
  return require("snacks.picker.source.proc").proc(vim.tbl_deep_extend("force", {
    cmd = "git",
    args = args,
    ---@param item snacks.picker.finder.Item
    transform = function(item)
      local status, file = item.text:sub(1, 2), item.text:sub(4)
      item.cwd = cwd
      item.status = status
      item.file = file
    end,
  }, opts or {}))
end

---@param opts snacks.picker.Config
---@type snacks.picker.finder
function M.diff(_opts)
  return require("snacks.picker.core.picker").new({
    finder = function()
      local output = vim.system({ "git", "diff" }):wait().stdout
      ---@type snacks.picker.finder.Item[]
      local results = {}
      ---@type string | nil
      local filename = nil
      ---@type number | nil
      local linenumber = nil
      ---@type string[]
      local hunk = {}

      for _, line in ipairs(vim.split(output or "", "\n")) do
        -- new file
        if vim.startswith(line, "diff") then
          -- Start of a new hunk
          if hunk[1] ~= nil then
            ---@type snacks.picker.finder.Item
            local item = { file = filename, pos = { linenumber, 0 }, raw_lines = hunk }
            table.insert(results, item)
          end

          filename = line:match("^diff .* a/(.*) b/.*$")
          linenumber = nil

          hunk = {}
        elseif vim.startswith(line, "@") then
          if filename ~= nil and linenumber ~= nil and #hunk > 0 then
            table.insert(results, { file = filename, pos = { linenumber, 0 }, raw_lines = hunk })
            hunk = {}
          end
          -- Hunk header
          -- @example "@@ -157,20 +157,6 @@ some content"
          local linenr_str = string.match(line, "@@ %-.*,.* %+(.*),.* @@")
          linenumber = tonumber(linenr_str)
          hunk = {}
          table.insert(hunk, line)
        else
          table.insert(hunk, line)
        end
      end
      -- Add the last hunk to the table
      if hunk[1] ~= nil and filename and linenumber and hunk then
        table.insert(results, { file = filename, pos = { linenumber, 0 }, raw_lines = hunk })
      end

      local function get_diff_line_idx(lines)
        for i, line in ipairs(lines) do
          if vim.startswith(line, "-") or vim.startswith(line, "+") then
            return i
          end
        end
        return -1
      end

      for _, v in ipairs(results) do
        local diff_line_idx = get_diff_line_idx(v.raw_lines)
        diff_line_idx = math.max(
          -- first line is header, next one is already handled
          diff_line_idx - 2,
          0
        )
        v.pos[1] = v.pos[1] + diff_line_idx
      end

      return results
    end,
    preview = function(ctx)
      local buf = ctx.preview:scratch()

      vim.bo[buf].modifiable = true
      local lines = vim.split(table.concat(ctx.item.raw_lines, "\n"), "\n")
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      vim.bo[buf].modifiable = false

      vim.bo[buf].filetype = "diff"

      return true
    end,
  })
end

return M
