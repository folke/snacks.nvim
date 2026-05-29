---@module 'luassert'

describe("snacks.spawn.resolve_cmd", function()
  local Spawn = require("snacks.util.spawn")

  local is_windows = (vim.uv or vim.loop).os_uname().sysname:lower():find("windows") ~= nil

  it("returns non-string input unchanged", function()
    assert.are.same(nil, Spawn.resolve_cmd(nil))
  end)

  it("returns empty string unchanged", function()
    assert.are.same("", Spawn.resolve_cmd(""))
  end)

  it("returns an absolute POSIX path unchanged", function()
    assert.are.same("/usr/bin/rg", Spawn.resolve_cmd("/usr/bin/rg"))
  end)

  it("returns a Windows-style backslash path unchanged", function()
    assert.are.same([[C:\Tools\rg.exe]], Spawn.resolve_cmd([[C:\Tools\rg.exe]]))
  end)

  if not is_windows then
    it("returns a bare command unchanged on non-Windows", function()
      -- On POSIX, libuv's spawn searches PATH for bare names, so resolve_cmd
      -- is a no-op for bare commands like "rg" or "git".
      assert.are.same("rg", Spawn.resolve_cmd("rg"))
      assert.are.same("git", Spawn.resolve_cmd("git"))
    end)
  end
end)
