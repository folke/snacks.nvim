---@module 'luassert'

local layout_mod = require("snacks.layout")
local win_mod = require("snacks.win")

describe("layout.footer_keys", function()
  it("shows footer keys for focused child and auto border when unspecified", function()
    local w1 = win_mod.new({ show = false, keys = { q = "close", ["<CR>"] = "confirm" }, footer_keys = true })
    local w2 = win_mod.new({ show = false, keys = { q = "close", h = "help" }, footer_keys = true })
    local layout = layout_mod.new({
      wins = { a = w1, b = w2 },
      footer_keys = true,
      layout = { box = "horizontal", width = 0.5, height = 0.3 },
    })
    vim.schedule(function()
      layout:update_footer()
    end)
    vim.wait(50)
    assert.is_true(layout.root:has_border(), "root should have auto border when unspecified")
    assert.is_not_nil(layout.root.opts.footer)
    local footer = layout.root.opts.footer
    local found_q, found_cr = false, false
    for _, cell in ipairs(footer) do
      if cell[1]:find("<CR>") then
        found_cr = true
      end
      if cell[1]:find("q") then
        found_q = true
      end
    end
    assert.is_true(found_q and found_cr, "footer should include keys from focused window")
    layout:close()
  end)

  it("does not inject border when border = none", function()
    local w = win_mod.new({ show = false, keys = { q = "close" }, footer_keys = true })
    local layout = layout_mod.new({
      wins = { a = w },
      footer_keys = true,
      layout = { box = "horizontal", width = 0.4, height = 0.2, border = "none" },
    })
    vim.schedule(function()
      layout:update_footer()
    end)
    vim.wait(50)
    assert.is_false(layout.root:has_border(), "root should NOT have border when explicitly none")
    assert.is_not_nil(layout.root.opts.footer)
    layout:close()
  end)

  it("restricts footer keys when list provided", function()
    local w =
      win_mod.new({ show = false, keys = { q = "close", h = "help", ["<CR>"] = "confirm" }, footer_keys = true })
    local layout = layout_mod.new({
      wins = { a = w },
      footer_keys = { "q", "<CR>" },
      layout = { box = "horizontal", width = 0.4, height = 0.2 },
    })
    vim.schedule(function()
      layout:update_footer()
    end)
    vim.wait(50)
    local footer = layout.root.opts.footer
    local count = 0
    for _, cell in ipairs(footer) do
      if cell[2] == "SnacksFooterKey" then
        count = count + 1
        assert.is_true(cell[1]:find("<CR>") or cell[1]:find("q"), "Only q and <CR> should appear")
      end
    end
    assert.is_true(count >= 2, "Expected at least q and <CR> keys displayed")
    layout:close()
  end)

  it("applies footer_max_keys (window only)", function()
    local w = win_mod.new({
      show = false,
      keys = { q = "close", h = "help", ["<CR>"] = "confirm" },
      footer_keys = true,
      footer_max_keys = 1,
    })
    local layout = layout_mod.new({
      wins = { a = w },
      footer_keys = true,
      layout = { box = "horizontal", width = 0.4, height = 0.2 },
    })
    vim.schedule(function()
      layout:update_footer()
    end)
    vim.wait(50)
    local footer = layout.root.opts.footer
    local key_count = 0
    for _, cell in ipairs(footer) do
      if cell[2] == "SnacksFooterKey" then
        key_count = key_count + 1
      end
    end
    assert.equals(1, key_count, "Should only show 1 key due to window footer_max_keys")
    layout:close()
  end)

  it("applies footer_max_keys (layout only)", function()
    local w =
      win_mod.new({ show = false, keys = { q = "close", h = "help", ["<CR>"] = "confirm" }, footer_keys = true })
    local layout = layout_mod.new({
      wins = { a = w },
      footer_keys = true,
      footer_max_keys = 2,
      layout = { box = "horizontal", width = 0.4, height = 0.2 },
    })
    vim.schedule(function()
      layout:update_footer()
    end)
    vim.wait(50)
    local footer = layout.root.opts.footer
    local key_count = 0
    for _, cell in ipairs(footer) do
      if cell[2] == "SnacksFooterKey" then
        key_count = key_count + 1
      end
    end
    assert.equals(2, key_count, "Should only show 2 keys due to layout footer_max_keys")
    layout:close()
  end)

  it("applies min(window,max(layout))", function()
    local w = win_mod.new({
      show = false,
      keys = { q = "close", h = "help", ["<CR>"] = "confirm" },
      footer_keys = true,
      footer_max_keys = 3,
    })
    local layout = layout_mod.new({
      wins = { a = w },
      footer_keys = true,
      footer_max_keys = 2,
      layout = { box = "horizontal", width = 0.4, height = 0.2 },
    })
    vim.schedule(function()
      layout:update_footer()
    end)
    vim.wait(50)
    local footer = layout.root.opts.footer
    local key_count = 0
    for _, cell in ipairs(footer) do
      if cell[2] == "SnacksFooterKey" then
        key_count = key_count + 1
      end
    end
    assert.equals(2, key_count, "Should show min(window.footer_max_keys, layout.footer_max_keys)=2")
    layout:close()
  end)

  it("handles footer_max_keys=0 (show none)", function()
    local w = win_mod.new({ show = false, keys = { q = "close", h = "help" }, footer_keys = true, footer_max_keys = 0 })
    local layout = layout_mod.new({
      wins = { a = w },
      footer_keys = true,
      layout = { box = "horizontal", width = 0.4, height = 0.2 },
    })
    vim.schedule(function()
      layout:update_footer()
    end)
    vim.wait(50)
    local footer = layout.root.opts.footer
    local key_count = 0
    for _, cell in ipairs(footer) do
      if cell[2] == "SnacksFooterKey" then
        key_count = key_count + 1
      end
    end
    assert.equals(0, key_count, "Should show 0 keys when footer_max_keys=0")
    layout:close()
  end)
end)

describe("layout.footer_keys mode filtering", function()
  local orig_get_mode
  local function with_mode(mode, fn)
    orig_get_mode = orig_get_mode or vim.api.nvim_get_mode
    vim.api.nvim_get_mode = function() return { mode = mode } end
    fn()
    vim.api.nvim_get_mode = orig_get_mode
  end
  local function new_layout()
    local w = win_mod.new({
      show = false,
      footer_keys = true,
      keys = {
        q = { "q", "close", desc = "Close", mode = "n" },
        both = { "b", "both", desc = "Both", mode = { "n", "v" } },
        only_v = { "v", "visual", desc = "Visual", mode = "v" },
        insert_i = { "i", "insert", desc = "Insert", mode = "i" },
        replace_r = { "r", "replace", desc = "Replace", mode = "R" },
        visual_x = { "x", "xmode", desc = "XMode", mode = "x" },
        op_pend = { "o", "opend", desc = "OpPending", mode = "o" },
        cmd_line = { "c", "cmd", desc = "Cmd", mode = "c" },
        term_key = { "t", "term", desc = "Term", mode = "t" },
      },
    })
    local layout = layout_mod.new({ wins = { a = w }, footer_keys = true, layout = { box = "horizontal", width = 0.3, height = 0.2 } })
    vim.wait(50) -- wait for scheduled show
    return layout
  end
  local function count_keys(footer)
    local n = 0
    for _, cell in ipairs(footer) do if cell[2] == "SnacksFooterKey" then n = n + 1 end end
    return n
  end
  it("shows normal keys in normal mode", function()
    local layout = new_layout()
    with_mode("n", function()
      layout:update_footer()
      local footer = layout.root.opts.footer
      assert.is_not_nil(footer)
      assert.equals(3, count_keys(footer))
    end)
    layout:close()
  end)
  it("shows insert + replace in insert mode", function()
    local layout = new_layout()
    with_mode("i", function()
      layout:update_footer()
      local footer = layout.root.opts.footer
      assert.is_not_nil(footer)
      assert.equals(2, count_keys(footer))
    end)
    layout:close()
  end)
  it("shows visual + x + multi-mode in visual mode", function()
    local layout = new_layout()
    with_mode("v", function()
      layout:update_footer()
      local footer = layout.root.opts.footer
      assert.is_not_nil(footer)
      assert.equals(3, count_keys(footer))
    end)
    layout:close()
  end)
end)
