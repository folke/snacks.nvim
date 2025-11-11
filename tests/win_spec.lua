---@module 'luassert'
local say = require("say")

local win_mod = require("snacks.win")

describe("win.build_footer_keys mode filtering", function()
  local orig_get_mode

  local function with_mode(mode, fn)
    orig_get_mode = orig_get_mode or vim.api.nvim_get_mode
    vim.api.nvim_get_mode = function()
      return { mode = mode }
    end
    fn()
    vim.api.nvim_get_mode = orig_get_mode
  end

  local function new_win()
    return win_mod.new({
      show = false,
      footer_keys = true,
      keys = {
        -- override the default q/close for testing
        q = { "q", "no_mode", desc = "No mode" },
        normal = { "n", "normal", desc = "Normal", mode = "n" },
        visual = { "v", "visual", desc = "Visual", mode = "v" },
        insert = { "i", "insert", desc = "Insert", mode = "i" },
        visual_x = { "x", "visual_x", desc = "Visual Only", mode = "x" },
        select = { "s", "select", desc = "Select", mode = "s" },
        op_pend = { "o", "opend", desc = "OpPending", mode = "o" },
        cmd = { "c", "cmd", desc = "Cmd", mode = "c" },
        term = { "t", "term", desc = "Term", mode = "t" },
        multi = { "m", "multi", desc = "Multi", mode = { "n", "v" } },
      },
    })
  end

  local function footer_keys(footer)
    local keys = {}
    for _, cell in ipairs(footer) do
      if cell[2] == "SnacksFooterKey" then
        local key = cell[1]:gsub("%s+", "")
        table.insert(keys, key)
      end
    end
    return keys
  end

  local function has_key(state, arguments)
    local table = arguments[1]
    local element = arguments[2]
    for _, value in ipairs(table) do
      if value == element then
        return true
      end
    end
    return false
  end

  say:set("assertion.key.positive", "Expected %s to contain: %s")
  say:set("assertion.key.negative", "Expected %s to not contain: %s")
  assert:register("assertion", "key", has_key, "assertion.key.positive", "assertion.key.negative")

  it("shows normal + multi-mode + no-mode keys in normal mode", function()
    local w = new_win()
    with_mode("n", function()
      local footer = w:build_footer_keys(nil)
      local keys = footer_keys(footer)
      assert.equals(3, #keys)
      assert.has.key(keys, "n", "Should show n key in insert mode")
      assert.has.key(keys, "m", "Should show m key in insert mode")
      assert.has.key(keys, "q", "Should show p key in insert mode")
    end)
    w:close()
  end)

  it("shows insert in insert mode", function()
    local w = new_win()
    with_mode("i", function()
      local footer = w:build_footer_keys(nil)
      local keys = footer_keys(footer)
      assert.equals(1, #keys)
      assert.has.key(keys, "i", "Should show i key in insert mode")
    end)
    w:close()
  end)

  it("shows visual + x + multi-mode keys in visual mode", function()
    local w = new_win()
    with_mode("v", function()
      local footer = w:build_footer_keys(nil)
      local keys = footer_keys(footer)
      assert.equals(3, #keys)
      assert.has.key(keys, "v", "Should show v key in insert mode")
      assert.has.key(keys, "x", "Should show x key in insert mode")
      assert.has.key(keys, "m", "Should show m key in insert mode")
    end)
    w:close()
  end)

  it("shows operator-pending key in operator-pending mode", function()
    local w = new_win()
    with_mode("o", function()
      local footer = w:build_footer_keys(nil)
      local keys = footer_keys(footer)
      assert.equals(1, #keys)
      assert.has.key(keys, "o", "Should contain only operator-pending key o")
    end)
    w:close()
  end)

  it("shows command-line key in command-line mode", function()
    local w = new_win()
    with_mode("c", function()
      local footer = w:build_footer_keys(nil)
      local keys = footer_keys(footer)
      assert.equals(1, #keys)
      assert.has.key(keys, "c", "Should contain only command-line key c")
    end)
    w:close()
  end)

  it("shows terminal key in terminal mode", function()
    local w = new_win()
    with_mode("t", function()
      local footer = w:build_footer_keys(nil)
      local keys = footer_keys(footer)
      assert.equals(1, #keys)
      assert.has.key(keys, "t", "Should contain only terminal key t")
    end)
    w:close()
  end)

  it("respects max parameter when provided", function()
    local w = new_win()
    with_mode("i", function()
      local footer = w:build_footer_keys(nil, 1)
      local keys = footer_keys(footer)
      assert.equals(1, #keys)
    end)
    w:close()
  end)

  it("respects want list filter", function()
    local w = new_win()
    with_mode("n", function()
      local footer = w:build_footer_keys({ "m" })
      local keys = footer_keys(footer)
      assert.equals(1, #keys)
      assert.has.key(keys, "m", "Should only show key m when filtered")
    end)
    w:close()
  end)

  it("shows select + visual + multi-modes keys in select mode", function()
    local w = new_win()
    with_mode("s", function()
      local footer = w:build_footer_keys(nil)
      local keys = footer_keys(footer)
      assert.equals(3, #keys)
      assert.has.key(keys, "s", "Should show s key in select mode")
      assert.has.key(keys, "v", "Should show v key in select mode")
      assert.has.key(keys, "m", "Should show m key in select mode")
    end)
    w:close()
  end)

  it("shows insert keys for replace visual mode", function()
    local w = new_win()
    with_mode("Rv", function()
      local footer = w:build_footer_keys(nil)
      local keys = footer_keys(footer)
      assert.equals(1, #keys)
      assert.has.key(keys, "i", "Should show i key for replace visual mode")
    end)
    w:close()
  end)

  it("shows visual keys in block visual mode", function()
    local w = new_win()
    with_mode("\22", function()
      local footer = w:build_footer_keys(nil)
      local keys = footer_keys(footer)
      assert.equals(3, #keys)
      assert.has.key(keys, "v", "Should show v key in block visual mode")
      assert.has.key(keys, "x", "Should show x key in block visual mode")
      assert.has.key(keys, "m", "Should show m key in block visual mode")
    end)
    w:close()
  end)
end)
