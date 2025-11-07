---@private
---@class snacks.bigfile
local M = {}

M.meta = {
  desc = "Deal with big files",
  needs_setup = true,
}

---@class snacks.bigfile.Config
---@field enabled? boolean
local defaults = {
  notify = true, -- show notification when big file detected
  size = 1.5 * 1024 * 1024, -- 1.5MB
  line_length = 1000, -- average line length (useful for minified files)
  -- Enable or disable features when big file detected
  ---@param ctx {buf: number, ft:string}
  setup = function(ctx)
    if vim.fn.exists(":NoMatchParen") ~= 0 then
      vim.cmd([[NoMatchParen]])
    end
    Snacks.util.wo(0, { foldmethod = "manual", statuscolumn = "", conceallevel = 0 })
    vim.b.completion = false
    vim.b.minianimate_disable = true
    vim.b.minihipatterns_disable = true
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(ctx.buf) then
        vim.bo[ctx.buf].syntax = ctx.ft
      end
    end)
  end,
}

---@private
function M.setup()
  local opts = Snacks.config.get("bigfile", defaults)

  vim.filetype.add({
    pattern = {
      [".*"] = {
        function(path, buf)
          if not path or not buf or vim.bo[buf].filetype == "bigfile" then
            return
          end
          if path ~= vim.fs.normalize(vim.api.nvim_buf_get_name(buf)) then
            return
          end
          local size = vim.fn.getfsize(path)
          if size <= 0 then
            return
          end
          if size > opts.size then
            return "bigfile"
          end
          local lines = vim.api.nvim_buf_line_count(buf)
          return (size - lines) / lines > opts.line_length and "bigfile" or nil
        end,
      },
    },
  })

  vim.api.nvim_create_autocmd({ "FileType" }, {
    group = vim.api.nvim_create_augroup("snacks_bigfile", { clear = true }),
    pattern = "bigfile",
    callback = function(ev)
      if opts.notify then
        local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(ev.buf), ":p:~:.")
        Snacks.notify.warn({
          ("Big file detected `%s`."):format(path),
          "Some Neovim features have been **disabled**.",
        }, { title = "Big File" })
      end
      vim.api.nvim_buf_call(ev.buf, function()
        opts.setup({
          buf = ev.buf,
          ft = vim.filetype.match({ buf = ev.buf }) or "",
        })
      end)
    end,
  })
end

return M
