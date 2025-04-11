---@module 'luassert'

local M = {}

---@param lines string|string[]
---@param opts? {ft?: string, ts?: boolean}
function M.set_lines(lines, opts)
  opts = opts or {}
  lines = type(lines) == "string" and vim.split(lines, "\n") or lines
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines --[[ @as string[] ]])
  vim.bo.filetype = opts.ft or ""
  vim.treesitter.stop()
  assert(not vim.b.ts_highlight, "treesitter highlight is still enabled")
  vim.b.snacks_ts = nil
  if opts.ts then
    vim.treesitter.start()
    assert(vim.b.ts_highlight, "treesitter highlight is not enabled")
  end
end

function M.inspect(v)
  return vim.inspect(v):gsub("%s+", " ")
end

local test = [[
function foo()
  while true do
    if x == 1 then
      break
    end
    local y = 2
  end
end
]]

describe("scope", function()
  local tests = {
    [1] = { 1, 8 },
    [2] = { 2, 7 },
    [3] = { 3, 5 },
    [4] = { 3, 5 },
    [5] = { 3, 5 },
    [6] = { 2, 7 },
    [7] = { 2, 7 },
    [8] = { 1, 8 },
  }
  Snacks.config.scope = {
    cursor = false,
    min_size = 2,
    treesitter = {
      blocks = false,
    },
  }

  for _, ws in ipairs({ false, true }) do
    local lines = vim.split(vim.trim(test), "\n")

    local t = vim.deepcopy(tests)

    if ws == true then
      local c = #lines
      -- insert empty lines
      for i = 1, c do
        table.insert(lines, i * 2, "")
      end
      local test2 = {}
      -- transform tests
      for line, s in pairs(t) do
        test2[line * 2 - 1] = { s[1] * 2 - 1, s[2] * 2 - 1 }
      end
      t = test2
    end

    for _, ts in ipairs({ true, false }) do
      for line, s in pairs(t) do
        it("should get scope " .. M.inspect({ line = line, scope = s, ts = ts, ws = ws }), function()
          M.set_lines(lines, {
            ft = "lua",
            ts = ts,
          })
          Snacks.scope.get(function(scope)
            assert(scope)
            assert((scope.node == nil) == not ts)
            assert.same(scope.from, s[1])
            assert.same(scope.to, s[2])
          end, {
            pos = { line, 0 },
            treesitter = { enabled = ts },
          })
        end)
      end
    end
  end
end)

local function foo()
  while true do
    -- doo

    if x == 1 and false then
      break
    end

    local y = 2
    local y = 2
  end
end
