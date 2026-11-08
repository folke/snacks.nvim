---@module "luassert"

local Actions = require("snacks.gh.actions")

describe("gh_open", function()
  it("jumps from the originating preview to the picker's main window", function()
    local main = vim.api.nvim_get_current_win()
    local previous = vim.api.nvim_win_get_buf(main)
    local buf = vim.api.nvim_create_buf(false, true)
    local item = { text = "Issue", buf = buf }
    local picker = Snacks.picker.pick({
      items = { item },
      format = "text",
      show_delay = 0,
      auto_close = false,
      layout = "default",
    })

    local ready = vim.wait(2000, function()
      return picker.preview.win:valid() and picker.preview.win.buf == buf
    end)
    local closed, opened
    if ready then
      vim.cmd.stopinsert()
      Actions.actions.gh_open.action(item, { items = { item }, main = picker.preview.win.win, action = {} })
      closed = picker.closed
      opened = vim.api.nvim_get_current_win() == main and vim.api.nvim_win_get_buf(main) == buf
    end
    if not picker.closed then
      picker:close()
    end
    if vim.api.nvim_buf_is_valid(previous) then
      vim.api.nvim_win_set_buf(main, previous)
    end
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end

    assert.is_true(ready)
    assert.is_true(closed)
    assert.is_true(opened)
  end)
end)
