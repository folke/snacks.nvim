---@module 'luassert'

describe("picker resume", function()
  local Picker = require("snacks.picker.core.picker")
  local Finder = require("snacks.picker.core.finder")

  describe("finder restore method", function()
    it("should restore items without re-running finder", function()
      local finder = Finder.new(function()
        return { { text = "original", idx = 1 } }
      end)

      local cached_items = {
        { text = "cached1", idx = 1 },
        { text = "cached2", idx = 2 },
        { text = "cached3", idx = 3 },
      }

      local mock_filter = { search = "", source_id = nil }
      finder:restore(cached_items, mock_filter)

      assert.are.same(cached_items, finder.items)
      assert.are.same(mock_filter, finder.filter)
      -- After restore, task should be nop (not running)
      assert.is_falsy(finder:running())
    end)

    it("should abort current task when restoring", function()
      local finder = Finder.new(function()
        return {}
      end)

      -- Simulate a running task
      finder.task = require("snacks.picker.util.async").new(function()
        vim.wait(1000)
      end)

      local cached_items = { { text = "cached", idx = 1 } }
      local mock_filter = { search = "test", source_id = nil }
      finder:restore(cached_items, mock_filter)

      assert.are.same(cached_items, finder.items)
      assert.are.same(mock_filter, finder.filter)
      -- After restore, task should be nop (not running)
      assert.is_falsy(finder:running())
    end)

    it("should handle empty items array", function()
      local finder = Finder.new(function()
        return { { text = "original", idx = 1 } }
      end)

      local mock_filter = { search = "", source_id = nil }
      finder:restore({}, mock_filter)

      assert.are.same({}, finder.items)
      assert.are.same(mock_filter, finder.filter)
    end)
  end)

  describe("M.last storage", function()
    it("should store finder items on close", function()
      -- Create a buffer for the picker
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "test line" })

      local picker = Picker.new({
        source = "buffers",
        buf = buf,
      })

      -- Manually set some items
      picker.finder.items = {
        { text = "item1", idx = 1 },
        { text = "item2", idx = 2 },
      }

      picker:close()

      -- Wait for scheduled cleanup to complete
      vim.wait(50, function()
        return false
      end)

      assert.is_not_nil(Picker.last)
      assert.is_not_nil(Picker.last.items)
      assert.equals(2, #Picker.last.items)
      assert.equals("item1", Picker.last.items[1].text)
      assert.equals("item2", Picker.last.items[2].text)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should keep items cached even after cleanup runs", function()
      -- Create a buffer for the picker
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "test line" })

      local picker = Picker.new({
        source = "lsp_references",
        buf = buf,
        finder = function()
          return { { text = "lsp1", idx = 1, buf = buf } }
        end,
      })

      picker.finder.items = {
        { text = "lsp_item1", idx = 1, buf = buf },
        { text = "lsp_item2", idx = 2, buf = buf },
      }

      picker:close()

      -- Wait for scheduled cleanup to complete (vim.schedule in close())
      vim.wait(100, function()
        return false
      end)

      -- Items should still be in M.last even after cleanup
      assert.is_not_nil(Picker.last)
      assert.is_not_nil(Picker.last.items)
      assert.equals(2, #Picker.last.items)
      assert.equals("lsp_item1", Picker.last.items[1].text)
      assert.equals("lsp_item2", Picker.last.items[2].text)

      -- Wait more time to ensure GC doesn't affect it
      vim.wait(200, function()
        return false
      end)
      collectgarbage("collect")

      -- Still should be available
      assert.is_not_nil(Picker.last)
      assert.is_not_nil(Picker.last.items)
      assert.equals(2, #Picker.last.items)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("resume integration", function()
    it("should restore cached items for LSP sources", function()
      -- Setup: Create a picker with LSP source and close it
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "test" })

      local mock_lsp_items = {
        { text = "file1.lua:10", idx = 1, filename = "file1.lua", lnum = 10 },
        { text = "file2.lua:20", idx = 2, filename = "file2.lua", lnum = 20 },
      }

      -- Create picker with a mock LSP finder
      local picker = Picker.new({
        source = "lsp_references",
        buf = buf,
        finder = function()
          return mock_lsp_items
        end,
      })

      picker.finder.items = mock_lsp_items
      picker:close()

      -- Wait for scheduled cleanup to complete
      vim.wait(100, function()
        return false
      end)

      -- Items should still be cached in M.last
      assert.is_not_nil(Picker.last)
      assert.is_not_nil(Picker.last.items)
      assert.equals(2, #Picker.last.items)

      -- Resume the picker
      local resumed = Picker.resume()

      -- Wait for matcher to process items
      vim.wait(200, function()
        return not resumed:is_active()
      end)

      -- Verify items were restored to finder
      assert.is_not_nil(resumed)
      assert.is_not_nil(resumed.finder.items)
      assert.equals(2, #resumed.finder.items)
      assert.equals("file1.lua:10", resumed.finder.items[1].text)
      assert.equals("file2.lua:20", resumed.finder.items[2].text)

      -- Verify filter was set (prevents re-runs)
      assert.is_not_nil(resumed.finder.filter)

      resumed:close()

      -- Wait for cleanup
      vim.wait(50, function()
        return false
      end)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should NOT restore cached items for grep sources", function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "test" })

      local original_items = {
        { text = "grep result 1", idx = 1 },
      }

      local picker = Picker.new({
        source = "grep",
        buf = buf,
        finder = function()
          return { { text = "new grep result", idx = 1 } }
        end,
      })

      picker.finder.items = original_items
      picker:close()

      -- Wait for cleanup
      vim.wait(50, function()
        return false
      end)

      -- For grep sources (non-LSP), items should not be cached
      assert.is_not_nil(Picker.last)
      -- items field should be nil or empty for non-LSP sources
      assert.is_true(Picker.last.items == nil or #Picker.last.items == 0)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)
end)

