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
