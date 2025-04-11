---@module 'luassert'

local function d(v)
  return vim.inspect(v):gsub("%s+", " ")
end

describe("config", function()
  local tests = {
    {
      { 1, 2 },
      { 3, 4 },
      { 3, 4 },
    },
    {
      { 1, 2 },
      nil,
      { 1, 2 },
    },
    {
      { a = 1, b = 2 },
      { c = 3 },
      { a = 1, b = 2, c = 3 },
    },
    {
      { 1, 2, a = 1 },
      { 3, 4, b = 2 },
      { 3, 4, b = 2 },
    },
    {
      { 3, 4, b = 2 },
      { 1, 2 },
      { 1, 2 },
    },
    {
      { 1, 2, a = 1 },
      { b = 2 },
      { 1, 2, b = 2, a = 1 },
    },
  }
  for _, t in ipairs(tests) do
    it("merges correctly " .. d(t), function()
      local ret = Snacks.config.merge(t[1], t[2])
      assert.are.same(ret, t[3])
    end)
  end
end)
