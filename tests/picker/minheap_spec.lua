---@module 'luassert'

local MinHeap = require("snacks.picker.util.minheap")

describe("MinHeap", function()
  local values = {} ---@type number[]
  for i = 1, 2000 do
    values[i] = i
  end
  ---@param tbl number[]
  local function shuffle(tbl)
    for i = #tbl, 2, -1 do
      local j = math.random(i)
      tbl[i], tbl[j] = tbl[j], tbl[i]
    end
    return tbl
  end

  for _ = 1, 100 do
    it("should push and pop values correctly", function()
      local topk = MinHeap.new({ capacity = 10 })
      for _, v in ipairs(shuffle(values)) do
        topk:add(v)
      end

      table.sort(values, topk.cmp)
      local topn = vim.list_slice(values, 1, 10)
      assert.same(topn, topk:get())
    end)
  end
end)
