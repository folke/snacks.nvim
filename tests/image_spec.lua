---@module "luassert"

describe("image doc parser", function()
  local doc = require("snacks.image.doc")

  it("parses wikilink width from bare numbers", function()
    assert.are.same({ src = "test.png", width_px = 150 }, doc.parse("test.png|150", "link_text"))
  end)

  it("parses wikilink width from px suffix", function()
    assert.are.same({ src = "test.png", width_px = 150 }, doc.parse("test.png|150px", "link_text"))
  end)

  it("uses the first supported width option", function()
    assert.are.same({ src = "test.png", width_px = 150 }, doc.parse("test.png|caption|150px|300", "link_text"))
  end)

  it("ignores unsupported wikilink options", function()
    assert.are.same({ src = "test.png" }, doc.parse("test.png|right|50%", "link_text"))
  end)

  it("strips angle brackets for regular markdown links", function()
    assert.are.same({ src = "test.png" }, doc.parse("<test.png>", "link_destination"))
  end)

  it("converts pixel widths to terminal cells", function()
    local size = Snacks.image.terminal.size
    Snacks.image.terminal.size = function()
      return { cell_width = 10 }
    end
    assert.are.equal(15, doc.width(150))
    Snacks.image.terminal.size = size
  end)
end)

describe("image placement deletion", function()
  local image = require("snacks.image.image")

  it("deletes the requested placement id", function()
    local requests = {}
    local request = Snacks.image.terminal.request
    Snacks.image.terminal.request = function(opts)
      requests[#requests + 1] = opts
    end

    image.del({
      id = 42,
      placements = {
        [7] = true,
      },
    }, 7)

    Snacks.image.terminal.request = request
    assert.are.same({
      { a = "d", d = "i", i = 42, p = 7 },
      { a = "d", d = "i", i = 42 },
    }, requests)
  end)
end)
