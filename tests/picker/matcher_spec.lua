---@module 'luassert'

local M = {}
M.files = {
  "lua/snacks/animate/",
  "lua/snacks/animate/easing.lua",
  "lua/snacks/animate/init.lua",
  "lua/snacks/bigfile.lua",
  "lua/snacks/bufdelete.lua",
  "lua/snacks/dashboard.lua",
  "lua/snacks/debug.lua",
  "lua/snacks/dim.lua",
  "lua/snacks/git.lua",
  "lua/snacks/gitbrowse.lua",
  "lua/snacks/health.lua",
  "lua/snacks/indent.lua",
  "lua/snacks/init.lua",
  "lua/snacks/input.lua",
  "lua/snacks/lazygit.lua",
  "lua/snacks/meta/",
  "lua/snacks/meta/docs.lua",
  "lua/snacks/meta/init.lua",
  "lua/snacks/meta/types.lua",
  "lua/snacks/notifier.lua",
  "lua/snacks/notify.lua",
  "lua/snacks/picker/",
  "lua/snacks/picker/async.lua",
  "lua/snacks/picker/init.lua",
  "lua/snacks/picker/list.lua",
  "lua/snacks/picker/matcher.lua",
  "lua/snacks/picker/preview.lua",
  "lua/snacks/picker/queue.lua",
  "lua/snacks/picker/sorter.lua",
  "lua/snacks/picker/topk.lua",
  "lua/snacks/profiler/",
  "lua/snacks/profiler/core.lua",
  "lua/snacks/profiler/init.lua",
  "lua/snacks/profiler/loc.lua",
  "lua/snacks/profiler/picker.lua",
  "lua/snacks/profiler/tracer.lua",
  "lua/snacks/profiler/ui.lua",
  "lua/snacks/quickfile.lua",
  "lua/snacks/rename.lua",
  "lua/snacks/scope.lua",
  "lua/snacks/scratch.lua",
  "lua/snacks/scroll.lua",
  "lua/snacks/statuscolumn.lua",
  "lua/snacks/terminal.lua",
  "lua/snacks/toggle.lua",
  "lua/snacks/util.lua",
  "lua/snacks/win.lua",
  "lua/snacks/words.lua",
  "lua/snacks/zen.lua",
}

local function fuzzy(pattern)
  local chars = vim.split(pattern, "")
  local pat = table.concat(chars, ".*")
  return vim.tbl_filter(function(v)
    return v:find(pat)
  end, M.files)
end

describe("fuzzy matching", function()
  local matcher = require("snacks.picker.core.matcher").new()

  local tests = {
    { "mod.md", "md", { 5, 6 } },
  }

  for t, test in ipairs(tests) do
    it("should find optimal match for " .. t, function()
      matcher:init(test[2])
      local item = { text = test[1], idx = 1, score = 0 }
      local score = matcher:match(item)
      assert(score and score > 0, "no match found")
      local positions = matcher:positions(item).text
      assert.are.same(test[3], positions)
    end)
  end

  local patterns = { "snacks", "lua", "sgbs", "mark", "dcs", "xxx", "lsw" }
  local algos = { "fuzzy", "fuzzy_find" }
  for _, pattern in ipairs(patterns) do
    local chars = vim.split(pattern, "")
    local expect = fuzzy(pattern)
    for _, algo in ipairs(algos) do
      it(("should find fuzzy matches for %q with %s"):format(pattern, algo), function()
        local matches = {} ---@type string[]
        for _, file in ipairs(M.files) do
          if matcher[algo](matcher, file, file, chars) then
            table.insert(matches, file)
          end
        end
        assert.are.same(expect, matches)
      end)
    end
  end
end)
