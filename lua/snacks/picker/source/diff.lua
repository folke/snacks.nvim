local M = {}

---@class snacks.picker.diff.Config: snacks.picker.proc.Config
---@field cmd? string optional since diff can be passed as string
---@field group? boolean Group hunks by file
---@field diff? string|number diff string or buffer number

---@class snacks.picker.diff.hunk.Pos
---@field line number
---@field count number

---@class snacks.picker.Diff
---@field header string[]
---@field blocks snacks.picker.diff.Block[]

---@class snacks.picker.diff.Hunk
---@field diff string[]
---@field line number
---@field context? string
---@field left snacks.picker.diff.hunk.Pos old (normal) /ours (merge)
---@field right snacks.picker.diff.hunk.Pos new (normal) /working (merge)
---@field parents? snacks.picker.diff.hunk.Pos[] theirs (merge)

---@class snacks.picker.diff.Block
---@field unmerged? boolean
---@field file string
---@field left? string
---@field right? string
---@field header string[]
---@field hunks snacks.picker.diff.Hunk[]
---@field mode? {from:string, to:string}
---@field copy? {from:string, to:string}
---@field rename? {from:string, to:string}
---@field delete? string (mode of deleted file)
---@field new? string (mode of new file)
---@field similarity? number
---@field dissimilarity? number
---@field index? {from:string, to:string, mode:string}

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
    ---@param block snacks.picker.diff.Block
    local function add(file, line, diff, block)
      line = line or 1
      cb({
        text = file .. ":" .. line,
        diff = table.concat(diff, "\n"),
        file = file,
        cwd = cwd,
        rename = block.rename and block.rename.from or nil,
        block = block,
        pos = { line, 0 },
      })
    end

    local diff = M.parse(lines)
    for _, block in ipairs(diff.blocks) do
      local diffs = {} ---@type string[]
      for _, h in ipairs(block.hunks) do
        if opts.group then
          vim.list_extend(diffs, h.diff)
        else
          add(block.file, h.line, vim.list_extend(vim.deepcopy(block.header), h.diff), block)
        end
      end
      if opts.group or #block.hunks == 0 then
        local line = block.hunks[1] and block.hunks[1].line or 1
        add(block.file, line, vim.list_extend(vim.deepcopy(block.header), diffs), block)
      end
    end
  end
end

---@param lines string[]
function M.parse(lines)
  local hunk ---@type snacks.picker.diff.Hunk?
  local block ---@type snacks.picker.diff.Block?
  local ret = {} ---@type snacks.picker.diff.Block[]
  local header = {} ---@type string[]

  ---@param file? string
  ---@param strip_prefix? boolean
  ---@return string?
  local function norm(file, strip_prefix)
    if file then
      file = file:gsub("\t.*$", "") -- remove tab and after
      file = file:gsub('^"(.-)"$', "%1") -- remove quotes
      if file == "/dev/null" then -- no file
        return
      end
      if strip_prefix == false then
        return file
      end
      local prefix = { "a", "b", "i", "w", "c", "o", "old", "new" }
      for _, s in ipairs(prefix) do -- remove prefixes
        if file:sub(1, #s + 1) == s .. "/" then
          return file:sub(#s + 2)
        end
      end
      return file
    end
  end

  local function emit()
    if block and hunk then
      hunk = nil
    elseif not block then
      return
    end
    for _, line in ipairs(block.header) do
      if line:find("^%-%-%- ") then
        block.left = norm(line:sub(5))
      elseif line:find("^%+%+%+ ") then
        block.right = norm(line:sub(5))
      elseif line:find("^rename from") then
        block.rename = block.rename or {}
        block.left = norm(line:match("^rename from (.*)"), false)
        block.rename.from = block.left
      elseif line:find("^rename to") then
        block.rename = block.rename or {}
        block.right = norm(line:match("^rename to (.*)"), false)
        block.rename.to = block.right
      elseif line:find("^copy from") then
        block.copy = block.copy or {}
        block.left = norm(line:match("^copy from (.*)"), false)
        block.copy.from = block.left
      elseif line:find("^copy to") then
        block.copy = block.copy or {}
        block.right = norm(line:match("^copy to (.*)"), false)
        block.copy.to = block.right
      elseif line:find("^new file mode") then
        block.new = line:match("^new file mode (.*)")
      elseif line:find("^deleted file mode") then
        block.delete = line:match("^deleted file mode (.*)")
      elseif line:find("^old mode") then
        block.mode = block.mode or {}
        block.mode.from = line:match("^old mode (.*)")
      elseif line:find("^new mode") then
        block.mode = block.mode or {}
        block.mode.to = line:match("^new mode (.*)")
      elseif line:find("^similarity index") then
        local sim = line:match("^similarity index (%d+)%%")
        block.similarity = tonumber(sim) or 0
      elseif line:find("^dissimilarity index") then
        local dis = line:match("^dissimilarity index (%d+)%%")
        block.dissimilarity = tonumber(dis) or 0
      elseif line:find("^index ") then
        local from, to, mode = line:match("^index (%S+)%.%.(%S+)%s*(%d*)$")
        block.index = { from = from, to = to, mode = mode ~= "" and mode or nil }
      end
    end
    local first = block.header[1] or ""
    if not block.right and not block.left and first:find("^diff") then
      -- no left/right so for sure no rename.
      -- this means the diff header is for the same file
      if first:find("^diff %-%-cc") then
        block.left = norm(first:match("^diff %-%-cc (.+)$"))
        block.right = block.left
      else
        first = first:gsub("^diff ", ""):gsub("^%s*%-%S+%s*", "") --[[@as string]]
        local idx = 1
        while idx <= #first do
          local s = first:find(" ", idx, true)
          if not s then
            break
          end
          idx = s + 1
          local l = norm(first:sub(1, s - 1))
          local r = norm(first:sub(s + 1))
          if l == r then
            block.left = l
            block.right = r
            break
          end
        end
      end
    end
    block.file = block.right or block.left or block.file
    table.sort(block.hunks, function(a, b)
      return a.line < b.line
    end)
    ret[#ret + 1] = block
    block = nil
  end

  local with_diff_header = false

  for _, text in ipairs(lines) do
    if not block and text:find("^%s*$") then
      -- Ignore empty lines before a diff block
    elseif text:find("^diff") or (not with_diff_header and text:find("^%-%-%- ") and (not block or hunk)) then
      with_diff_header = with_diff_header or text:find("^diff") == 1
      emit()
      block = {
        file = "", --file or "unknown",
        header = { text },
        hunks = {},
      }
    elseif text:find("@@", 1, true) == 1 and block then
      -- Hunk header
      hunk = M.parse_hunk_header(text)
      if hunk then
        block.unmerged = block.unmerged or (hunk.parents ~= nil) or nil
        block.hunks[#block.hunks + 1] = hunk
      else
        Snacks.notify.error("Invalid hunk header: " .. text, { title = "Snacks Picker Diff" })
      end
    elseif hunk then
      -- Hunk body
      hunk.diff[#hunk.diff + 1] = text
    elseif block then
      block.header[#block.header + 1] = text
    elseif #ret == 0 then
      header[#header + 1] = text
    else
      Snacks.notify.error("Unexpected line: " .. text, { title = "Snacks Picker Diff" })
    end
  end
  emit()
  ---@type snacks.picker.Diff
  return { blocks = ret, header = header }
end

---@param line string
function M.parse_hunk_header(line)
  local count_start, inner, count_end, context = line:match("^(@+)%s*(.-)%s*(@+)%s*(.*)$")
  if not count_start or not count_end or count_start ~= count_end or #count_start < 2 then
    return
  end
  local ret = {} ---@type {line:number, count:number}[]
  for _, part in ipairs(vim.split(inner, "%s+")) do
    local l, c = part:match("^[%-+](%d+),?(%d*)$")
    if not l then
      return
    end
    ret[#ret + 1] = { line = tonumber(l) or 1, count = tonumber(c) or 1 }
  end
  if #ret ~= #count_start then
    return
  end
  local right = table.remove(ret)
  ---@type snacks.picker.diff.Hunk
  return {
    diff = { line },
    line = right and right.line or 1,
    left = table.remove(ret, 1),
    right = right,
    parents = #ret > 0 and ret or nil,
    context = context ~= "" and context or nil,
  }
end

return M
