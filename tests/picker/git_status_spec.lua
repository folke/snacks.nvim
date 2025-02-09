---@module 'luassert'

local Git = require("snacks.picker.source.git")

describe("git status", function()
  -- git status codes are always 2 characters
  local tests = {
    -- Unmerged cases
    ["AA"] = { xy = "AA", status = "added", unmerged = true },
    ["UU"] = { xy = "UU", status = "modified", unmerged = true },
    ["AU"] = { xy = "AU", status = "added", unmerged = true },
    ["DD"] = { xy = "DD", status = "deleted", unmerged = true },
    ["UD"] = { xy = "UD", status = "deleted", unmerged = true },
    ["DU"] = { xy = "DU", status = "deleted", unmerged = true },
    ["UA"] = { xy = "UA", status = "added", unmerged = true },

    -- Regular cases
    [" M"] = { xy = " M", status = "modified" },
    [" D"] = { xy = " D", status = "deleted" },
    [" R"] = { xy = " R", status = "renamed" },
    ["??"] = { xy = "??", status = "untracked" },
    ["!!"] = { xy = "!!", status = "ignored" },

    -- Staged cases
    ["M "] = { xy = "M ", status = "modified", staged = true },
    ["T "] = { xy = "T ", status = "modified", staged = true },
    ["D "] = { xy = "D ", status = "deleted", staged = true },
    ["A "] = { xy = "A ", status = "added", staged = true },
    ["AD"] = { xy = "AD", status = "added", staged = true },
    ["C "] = { xy = "C ", status = "copied", staged = true },
  }
  for _, test in pairs(tests) do
    it("should parse `" .. test.xy .. "`", function()
      local status = Git.git_status(test.xy)
      status.priority = nil
      assert.are.same(test, status)
    end)
  end
end)
