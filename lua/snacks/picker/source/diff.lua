local M = {}

---@class snacks.picker.diff.Config: snacks.picker.proc.Config
---@field cmd? string optional since diff can be passed as string
---@field group? boolean Group hunks by file
---@field diff? string|number diff string or buffer number

---@class snacks.picker.diff.Hunk
---@field diff string[]
---@field line number

---@class snacks.picker.diff.Block
---@field file string
---@field header string[]
---@field hunks snacks.picker.diff.Hunk[]

---@param opts? snacks.picker.diff.Config
---@type snacks.picker.finder
function M.diff(opts, ctx)
  opts = opts or {}
  local lines = {} ---@type string[]
  local finder ---@type snacks.picker.finder.result?

  do
    if opts.cmd then
      finder = require("snacks.picker.source.proc").proc(opts, ctx)
    else
      local diff = opts.diff
      if not diff and vim.bo.filetype == "diff" then
        diff = 0
      end
      if type(diff) == "number" then
        lines = vim.api.nvim_buf_get_lines(diff, 0, -1, false)
      elseif type(diff) == "string" then
        lines = vim.split(diff, "\n", { plain = true })
      else
        Snacks.notify.error("snacks.picker.diff: opts.diff must be a string or buffer number")
        return {}
      end
    end
  end

  local cwd = ctx.filter.cwd
  return function(cb)
    if finder then
      finder(function(proc_item)
        lines[#lines + 1] = proc_item.text
      end)
    end

    ---@param file string
    ---@param line? number
    ---@param diff string[]
    local function add(file, line, diff)
      line = line or 1
      cb({
        text = file .. ":" .. line,
        diff = table.concat(diff, "\n"),
        file = file,
        cwd = cwd,
        pos = { line, 0 },
      })
    end

    local blocks = M.parse(lines)
    for _, block in ipairs(blocks) do
      local diff = {} ---@type string[]
      for _, h in ipairs(block.hunks) do
        if opts.group then
          vim.list_extend(diff, h.diff)
        else
          add(block.file, h.line, vim.list_extend(vim.deepcopy(block.header), h.diff))
        end
      end
      if opts.group or #block.hunks == 0 then
        local line = block.hunks[1] and block.hunks[1].line or 1
        add(block.file, line, vim.list_extend(vim.deepcopy(block.header), diff))
      end
    end
  end
end

---@param lines string[]
function M.parse(lines)
  local hunk ---@type snacks.picker.diff.Hunk?
  local block ---@type snacks.picker.diff.Block?
  local ret = {} ---@type snacks.picker.diff.Block[]

  local function emit()
    if block and hunk then
      hunk = nil
    end
    if block then
      table.sort(block.hunks, function(a, b)
        return a.line < b.line
      end)
      ret[#ret + 1] = block
      block = nil
    end
  end

  local with_diff_header = vim.trim(table.concat(lines, "\n")):find("^diff") ~= nil

  for _, text in ipairs(lines) do
    if not block and text:find("^%s*$") then
      -- Ignore empty lines before a diff block
    elseif text:find("^diff") or (not with_diff_header and text:find("^%-%-%- ") and (not block or hunk)) then
      emit()
      local file ---@type string?
      if text:find("^diff") then
        file = text:gsub("^diff%s*", ""):gsub("^%-%S+%s*", "")
        file = file:match('^"%a/(.-)"') or file:match("^%a/(.-) %a/") or file:match("^%a/(.*)$") or file
      elseif text:find("^%-%-%-") then
        file = text:match("^%-%-%- %a/([^\t]+)") or text:match("^%-%-%- ([^\t]+)")
      end
      block = {
        file = file or "unknown",
        header = { text },
        hunks = {},
      }
    elseif text:find("@@", 1, true) == 1 and block then
      -- Hunk header
      local line = 1
      if text:find("@@@", 1, true) == 1 then
        line = tonumber(text:match("^@@@ %-%d+,?%d* %-%d+,?%d* %+(%d+),?%d* @@@")) or 1
      else
        line = tonumber(text:match("^@@ %-%d+,?%d* %+(%d+),?%d* @@")) or 1
      end
      hunk = {
        line = line,
        diff = { text },
      }
      block.hunks[#block.hunks + 1] = hunk
    elseif hunk then
      -- Hunk body
      hunk.diff[#hunk.diff + 1] = text
    elseif block then
      -- File header
      block.header[#block.header + 1] = text
    else
      Snacks.notify.error("unexpected line: " .. text, { title = "Snacks Picker Diff" })
    end
  end
  emit()
  return ret
end

return M
