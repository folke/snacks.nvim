---@module 'luassert'

-- Path normalization used by the explorer tree (`norm` in explorer/tree.lua),
-- exercised through the public `Tree:find` / `Tree:node` behaviour.

---@return snacks.picker.explorer.Tree
local function new_tree()
  -- fresh instance per case, so cached nodes do not leak between tests
  return getmetatable(require("snacks.explorer.tree")).new()
end

describe("explorer tree normalization (POSIX)", function()
  -- creates `<tmp>/x` and passes the base dir to `fn`, cleaning up afterwards
  local function with_dir(fn)
    local base = vim.fs.normalize(vim.fn.tempname())
    vim.fn.mkdir(base .. "/x", "p")
    local ok, err = pcall(fn, base)
    vim.fn.delete(base, "rf")
    assert(ok, err)
  end

  it("keeps '/' as '/'", function()
    local tree = new_tree()
    local node = tree:find("/")
    assert.are.equal("/", node.path)
    assert.are.equal(node, tree:node("/"))
  end)

  it("maps the empty string to '/'", function()
    local tree = new_tree()
    assert.are.equal("/", tree:find("").path)
    assert.are.equal(tree:find("/"), tree:find(""))
  end)

  it("strips the trailing slash from a directory path", function()
    with_dir(function(base)
      local tree = new_tree()
      local dir = vim.fs.normalize(base .. "/x")
      local node = tree:find(dir .. "/")
      assert.are.equal(dir, node.path)
      assert.are.equal(node, tree:find(dir))
      assert.are.equal(node, tree:node(dir .. "/"))
    end)
  end)

  it("resolves a path with and without trailing slash to the same node", function()
    with_dir(function(base)
      local tree = new_tree()
      local dir = vim.fs.normalize(base .. "/x")
      assert.are.equal(tree:find(dir), tree:find(dir .. "/"))
    end)
  end)
end)

describe("explorer tree drive roots (Windows)", function()
  -- selene: allow(undefined_variable)
  local function skip_unless_windows()
    if vim.fn.has("win32") ~= 1 then
      MiniTest.skip("Windows only: drive roots do not exist on this platform")
    end
  end

  it("keeps the trailing separator of a drive root", function()
    skip_unless_windows()
    local tree = new_tree()
    local node = tree:find("D:/")
    assert.are.equal("D:/", node.path)
    assert.are.equal(node, tree:node("D:/"))
  end)

  it("strips the trailing slash from a directory under a drive root", function()
    skip_unless_windows()
    local tree = new_tree()
    assert.are.equal("D:/projects", tree:find("D:/projects/").path)
  end)
end)
