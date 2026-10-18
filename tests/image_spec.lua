---@module "luassert"

local image = require("snacks.image.image")
local terminal = require("snacks.image.terminal")

describe("image lifecycle", function()
  local request
  local requests

  before_each(function()
    request = terminal.request
    requests = {}
    terminal.request = function(opts)
      requests[#requests + 1] = opts
    end
  end)

  after_each(function()
    terminal.request = request
  end)

  local function new()
    return setmetatable({ id = 42, sent = true, placements = {}, fsize = 0 }, image)
  end

  it("deletes the requested placement without removing other placements of the same image", function()
    local img = new()
    img.placements = { [11] = {}, [12] = {} }
    img:del(12)
    assert.are.same({ { a = "d", d = "i", i = 42, p = 12 } }, requests)
    assert.is_not_nil(img.placements[11])
    assert.is_nil(img.placements[12])
    assert.is_true(img.sent)
  end)

  it("invalidates the terminal cache when the last placement is deleted", function()
    local img = new()
    img.placements[11] = {}
    img:del(11)
    assert.are.same({ a = "d", d = "I", i = 42 }, requests[#requests])
    assert.is_false(img.sent)
    assert.are.same({}, img.placements)
  end)

  it("deletes all placements by their actual ids", function()
    local img = new()
    img.placements = { [11] = {}, [12] = {} }
    img:del()
    local ids = {}
    for _, req in ipairs(requests) do
      if req.p then
        ids[#ids + 1] = req.p
      end
    end
    table.sort(ids)
    assert.are.same({ 11, 12 }, ids)
    assert.is_false(img.sent)
  end)

  it("recreates every placement after retransmitting shared image data", function()
    local img = new()
    local updates = 0
    for _, id in ipairs({ 11, 12 }) do
      img.placements[id] = {
        _state = {},
        update = function(p)
          assert.is_nil(p._state)
          updates = updates + 1
        end,
      }
    end
    img:on_send()
    assert.are.equal(2, updates)
  end)
end)
