---@module 'luassert'

describe("globs", function()
  local tests = {
    ["*.lua"] = "%.lua$",
    ["*/*.lua"] = "/[^/]*%.lua$",
    ["**/*.lua"] = "/[^/]*%.lua$",
    ["foo/**/bar/*.lua"] = "foo/.*/bar/[^/]*%.lua$",
    ["foo/*"] = "foo/",
    ["foo/**"] = "foo/",
    ["*.?sx"] = "%.[^/]sx$",
  }
  for glob, pattern in pairs(tests) do
    it("should convert glob to pattern: " .. glob, function()
      local result = Snacks.picker.util.glob2pattern(glob)
      assert.are.same(pattern, result)
    end)
  end
end)
