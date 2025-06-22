---@module 'luassert'

vim.g.mapleader = " "

describe("util.normkey", function()
  local normkey = require("snacks.util").normkey

  local tests = {
    ["<c-a>"] = "<C-A>",
    ["<C-A>"] = "<C-A>",
    ["<a-a>"] = "<M-a>",
    ["<a-A>"] = "<M-A>",
    ["<m-a>"] = "<M-a>",
    ["<m-A>"] = "<M-A>",
    ["<s-a>"] = "A",
    ["<c-j>"] = "<C-J>",
    ["<c-]>"] = "<C-]>",
    ["<c-\\>"] = "<C-\\>",
    ["<c-/>"] = "<C-/>",
    ["<Cr>"] = "<CR>",
    ["<c-down>"] = "<C-Down>",
    ["<scrollwheelUP>"] = "<ScrollWheelUp>",
    ["<c-scrollwheelUP>"] = "<C-ScrollWheelUp>",
    ["<Space>"] = "<Space>",
    ["<space>"] = "<Space>",
    ["<space><space>"] = "<Space><Space>",
    ["<leader>"] = "<Space>",
    ["<leader> "] = "<Space><Space>",
    ["<leader><leader>"] = "<Space><Space>",
    ["<p"] = "<p",
    ["<lt>p"] = "<p",
  }

  for input, expected in pairs(tests) do
    it('should normalize "' .. input .. '"', function()
      assert.are.equal(expected, normkey(input))
    end)
  end
end)

describe("util.bo", function()
  local util = require("snacks.util")

  -- Helper to count actual API calls by mocking vim.api.nvim_set_option_value
  local api_call_count = 0
  local original_set_option = vim.api.nvim_set_option_value

  before_each(function()
    api_call_count = 0
    vim.api.nvim_set_option_value = function(...)
      api_call_count = api_call_count + 1
      return original_set_option(...)
    end
  end)

  after_each(function()
    vim.api.nvim_set_option_value = original_set_option
  end)

  it("should set buffer options correctly", function()
    local buf = vim.api.nvim_create_buf(false, true)
    util.bo(buf, { buftype = "nofile", filetype = "lua" })

    -- Verify options were set
    assert.are.equal("nofile", vim.api.nvim_get_option_value("buftype", { buf = buf }))
    assert.are.equal("lua", vim.api.nvim_get_option_value("filetype", { buf = buf }))
    assert.are.equal(2, api_call_count)

    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  it("should cache options and avoid redundant API calls", function()
    local buf = vim.api.nvim_create_buf(false, true)

    -- First call should set options
    util.bo(buf, { buftype = "nofile", filetype = "lua" })
    assert.are.equal(2, api_call_count)

    -- Second call with same options should not call API
    api_call_count = 0
    util.bo(buf, { buftype = "nofile", filetype = "lua" })
    assert.are.equal(0, api_call_count)

    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  it("should detect changes and update only changed options", function()
    local buf = vim.api.nvim_create_buf(false, true)

    -- Set initial options
    util.bo(buf, { buftype = "nofile", filetype = "lua" })
    assert.are.equal(2, api_call_count)

    -- Change only one option
    api_call_count = 0
    util.bo(buf, { buftype = "nofile", filetype = "javascript" })
    assert.are.equal(1, api_call_count) -- Only filetype should be updated

    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  it("should handle empty or nil options", function()
    local buf = vim.api.nvim_create_buf(false, true)

    -- Should handle nil options
    util.bo(buf, nil)
    assert.are.equal(0, api_call_count)

    -- Should handle empty table
    util.bo(buf, {})
    assert.are.equal(0, api_call_count)

    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  it("should handle invalid buffers gracefully", function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_delete(buf, { force = true })

    -- Should not error with invalid buffer
    util.bo(buf, { buftype = "nofile" })
    assert.are.equal(0, api_call_count)
  end)

  it("should clean up cache when buffer is deleted", function()
    local buf = vim.api.nvim_create_buf(false, true)

    -- Set options to populate cache
    util.bo(buf, { buftype = "nofile" })
    assert.are.equal(1, api_call_count)

    -- Delete buffer (this should trigger cache cleanup via autocmd)
    vim.api.nvim_buf_delete(buf, { force = true })

    -- Processing autocmds
    vim.api.nvim_exec_autocmds("BufDelete", { buffer = buf })

    -- Create new buffer with same ID shouldn't use old cache
    local new_buf = vim.api.nvim_create_buf(false, true)
    api_call_count = 0
    util.bo(new_buf, { buftype = "nofile" })
    assert.are.equal(1, api_call_count) -- Should call API, not use cache

    vim.api.nvim_buf_delete(new_buf, { force = true })
  end)
end)
