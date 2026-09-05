---@module 'luassert'

describe("picker file preview", function()
  local Preview = require("snacks.picker.core.preview")
  local preview, path, opts
  local target_line = 4000
  local other_target_line = 5000
  local target_text = "😀 target"
  local file_lines = 6000
  local line_length = 210
  local preview_height = 10
  local slice_size = preview_height * 3
  local context = math.floor(slice_size / 2)
  local target_buf_line = context + 1

  local function source_line(i)
    if i == target_line then
      return target_text
    end
    return ("line %05d %s"):format(i, ("x"):rep(line_length + (i % 7)))
  end

  local function write_large_file()
    local lines = {}
    for i = 1, file_lines do
      lines[i] = source_line(i)
    end
    vim.fn.writefile(lines, path)
  end

  ---@param pos? snacks.picker.Pos
  ---@param loc? snacks.picker.lsp.Loc
  local function show(pos, loc)
    local prev = preview.item
    preview.item = {
      file = path,
      pos = pos,
      end_pos = loc and { pos[1], loc.range["end"].character } or nil,
      loc = loc,
    }
    require("snacks.picker.preview").file(setmetatable({
      picker = { opts = opts },
      preview = preview,
      item = preview.item,
      prev = prev,
    }, {
      __index = function(_, key)
        return key == "buf" and preview.win.buf or key == "win" and preview.win.win
      end,
    }))
  end

  local function preview_lines()
    return vim.api.nvim_buf_get_lines(preview.win.buf, 0, -1, false)
  end

  before_each(function()
    path = vim.fn.tempname() .. ".txt"
    write_large_file()
    opts = { previewers = { file = { max_size = 1024 * 1024, max_line_length = 500 } } }
    preview = setmetatable({
      win = Snacks.win({ width = 60, height = preview_height, show = true, wo = { number = true } }),
      state = {},
    }, Preview)
  end)

  after_each(function()
    preview.win:destroy()
    vim.fn.delete(path)
  end)

  it("previews a bounded range around an oversized target", function()
    assert.is_true(vim.uv.fs_stat(path).size > opts.previewers.file.max_size)
    show({ target_line, 0 })

    local displayed = preview_lines()
    assert.equals(slice_size, #displayed)
    assert.equals(source_line(target_line - context), displayed[1])
    assert.equals(source_line(target_line), displayed[target_buf_line])
    assert.same({ target_buf_line, 0 }, vim.api.nvim_win_get_cursor(preview.win.win))

    local number = vim.api.nvim_eval_statusline(vim.wo[preview.win.win].statuscolumn, {
      winid = preview.win.win,
      use_statuscol_lnum = target_buf_line,
    }).str
    assert.equals(tostring(target_line), vim.trim(number))
  end)

  it("keeps the warning and clears stale contents without a target", function()
    show({ target_line, 0 })
    show()

    assert.equals("warn: large file > 1MB", preview_lines()[1])
    assert.is_nil(table.concat(preview_lines(), "\n"):find(target_text, 1, true))
    assert.equals("", vim.wo[preview.win.win].statuscolumn)
  end)

  it("reloads a slice for another target in the same file", function()
    show({ target_line, 0 })
    show({ other_target_line, 0 })

    assert.equals(source_line(other_target_line - context), preview_lines()[1])
    assert.equals(source_line(other_target_line), preview_lines()[target_buf_line])
    assert.same({ target_buf_line, 0 }, vim.api.nvim_win_get_cursor(preview.win.win))

    local number = vim.api.nvim_eval_statusline(vim.wo[preview.win.win].statuscolumn, {
      winid = preview.win.win,
      use_statuscol_lnum = target_buf_line,
    }).str
    assert.equals(tostring(other_target_line), vim.trim(number))
  end)

  it("resolves an LSP column against the retained source line", function()
    local loc = {
      encoding = "utf-16",
      range = {
        start = { line = target_line - 1, character = 3 },
        ["end"] = { line = target_line - 1, character = 9 },
      },
    }
    show({ target_line, 3 }, loc)

    assert.same({ target_buf_line, 5 }, vim.api.nvim_win_get_cursor(preview.win.win))
    assert.is_nil(loc.resolved)
  end)

  it("keeps the full-file path for files within max_size", function()
    vim.fn.writefile({ "one", "two", "three" }, path)
    show({ 2, 0 })

    assert.same({ "one", "two", "three" }, preview_lines())
    assert.same({ 2, 0 }, vim.api.nvim_win_get_cursor(preview.win.win))

    local tick = vim.api.nvim_buf_get_changedtick(preview.win.buf)
    show({ 3, 0 })
    assert.equals(tick, vim.api.nvim_buf_get_changedtick(preview.win.buf))
    assert.same({ 3, 0 }, vim.api.nvim_win_get_cursor(preview.win.win))
  end)

  it("clears stale contents when the file is missing", function()
    preview:set_lines({ "stale" })
    vim.fn.delete(path)
    show({ 1, 0 })

    assert.equals("error: file not found: " .. path, preview_lines()[1])
    assert.is_nil(table.concat(preview_lines(), "\n"):find("stale", 1, true))
  end)
end)
