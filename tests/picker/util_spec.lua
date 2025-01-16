---@module 'luassert'

describe("input line col split", function()
  local util = require("snacks.picker.util")

  local tests = {
    { "foo:1", { "foo", { 1, 0 } } },
    { "foo:1:2", { "foo", { 1, 2 } } },
    { "foo:1:2:3", { "foo:1", { 2, 3 } } },
    { "foo:1:2:3:4", { "foo:1:2", { 3, 4 } } },
    { "foo:1:2:3:4:5", { "foo:1:2:3", { 4, 5 } } },
  }

  for t, test in ipairs(tests) do
    it("should split " .. t, function()
      local input, expected = unpack(test)
      local result, location = util.input_line_col_split(input)
      assert.are.same(expected[1], result)
      assert.are.same(expected[2], location)
    end)
  end
end)
