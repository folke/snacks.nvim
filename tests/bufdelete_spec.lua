---@module "luassert"

local bufdelete = require("snacks.bufdelete")

--- Helper function to create a test buffer with optional content
---@param content? string[]
---@param modified? boolean
---@return number buffer number
local function create_test_buffer(content, modified)
  local buf = vim.api.nvim_create_buf(true, false)
  if content then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
  end
  if modified then
    vim.bo[buf].modified = true
  else
    vim.bo[buf].modified = false
  end
  return buf
end

---@return number
local function count_listed_buffers()
  local count = 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
      count = count + 1
    end
  end
  return count
end

describe("bufdelete", function()
  before_each(function()
    vim.cmd("silent! %bwipeout!")
    vim.cmd("enew")
  end)

  describe("option parsing", function()
    it("should accept buffer number as direct argument", function()
      local buf = create_test_buffer()
      -- Should not error
      assert.has_no.errors(function()
        bufdelete.delete(buf)
      end)
    end)

    it("should accept options table", function()
      local buf = create_test_buffer()
      assert.has_no.errors(function()
        bufdelete.delete({ buf = buf, force = true })
      end)
    end)

    it("should handle nil argument", function()
      assert.has_no.errors(function()
        bufdelete.delete(nil)
      end)
    end)

    it("should handle empty options table", function()
      assert.has_no.errors(function()
        bufdelete.delete({})
      end)
    end)
  end)

  describe("error handling", function()
    it("should handle non-existent file gracefully", function()
      local initial_count = count_listed_buffers()
      
      assert.has_no.errors(function()
        bufdelete.delete({ file = "/nonexistent/file.txt" })
      end)
      
      assert.are.equal(initial_count, count_listed_buffers())
    end)

    it("should handle invalid buffer number gracefully", function()
      local initial_count = count_listed_buffers()
      
      assert.has_no.errors(function()
        bufdelete.delete(99999)
      end)
      
      assert.are.equal(initial_count, count_listed_buffers())
    end)

    it("should handle buffer 0 (current buffer alias)", function()
      assert.has_no.errors(function()
        bufdelete.delete({ buf = 0, force = true })
      end)
    end)
  end)

  describe("module interface", function()
    it("should be callable directly via metatable", function()
      local buf = create_test_buffer()
      assert.has_no.errors(function()
        bufdelete({ buf = buf, force = true })
      end)
    end)

    it("should have meta.desc field", function()
      assert.is_not_nil(bufdelete.meta)
      assert.is_string(bufdelete.meta.desc)
      assert.are.equal("Delete buffers without disrupting window layout", bufdelete.meta.desc)
    end)

    it("should have delete method", function()
      assert.is_function(bufdelete.delete)
    end)

    it("should have all method", function()
      assert.is_function(bufdelete.all)
    end)

    it("should have other method", function()
      assert.is_function(bufdelete.other)
    end)
  end)

  describe("filter functions", function()
    it("should accept filter in options table", function()
      create_test_buffer({ "buffer 1" })
      create_test_buffer({ "buffer 2" })
      
      assert.has_no.errors(function()
        bufdelete.delete({
          force = true,
          filter = function(b)
            return vim.api.nvim_buf_is_valid(b)
          end,
        })
      end)
    end)

    it("should only process listed buffers with filter", function()
      create_test_buffer({ "listed buffer" })
      local unlisted_buf = vim.api.nvim_create_buf(false, true)
      
      bufdelete.delete({
        force = true,
        filter = function()
          return true
        end,
      })
      
      -- Unlisted buffer should still exist
      assert.is_true(vim.api.nvim_buf_is_valid(unlisted_buf))
    end)
  end)
end)

