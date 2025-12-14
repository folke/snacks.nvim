---@module "luassert"

local terminal = require("snacks.terminal")

local tests = {
  { "bash", { "bash" } },
  { '"bash"', { "bash" } },
  {
    '"C:\\Program Files\\Git\\bin\\bash.exe"     -c "echo hello"',
    { "C:\\Program Files\\Git\\bin\\bash.exe", "-c", "echo hello" },
  },
  { "pwsh -NoLogo", { "pwsh", "-NoLogo" } },
  { 'echo "foo\tbar"', { "echo", "foo\tbar" } },
  { "echo\tfoo", { "echo", "foo" } },
  { 'this "is \\"a test"', { "this", 'is "a test' } },
}

describe("terminal.parse", function()
  for _, test in ipairs(tests) do
    it("should parse " .. test[1], function()
      local result = terminal.parse(test[1])
      assert.are.same(test[2], result)
    end)
  end
end)

describe("terminal.open", function()
  it("should set buffer when position is 'current'", function()
    -- Create a test buffer with content
    vim.cmd("enew")
    local test_buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "test content" })

    -- Open terminal with position='current'
    local term = terminal.open(nil, { win = { position = "current" } })

    -- Check that the current window now has the terminal buffer
    local current_win = vim.api.nvim_get_current_win()
    local current_buf = vim.api.nvim_win_get_buf(current_win)

    assert.are.equal(term.buf, current_buf, "Terminal buffer should be set in current window")
    assert.are.equal("terminal", vim.bo[current_buf].buftype, "Buffer should be a terminal")

    -- Clean up
    term:close()
  end)
end)
