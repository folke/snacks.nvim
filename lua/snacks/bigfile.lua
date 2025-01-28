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
  -- Enable or disable features when big file detected
  ---@param ctx {buf: number, ft:string}
  setup = function(ctx)
    if vim.fn.exists(":NoMatchParen") ~= 0 then
      vim.cmd([[NoMatchParen]])
    end
    Snacks.util.wo(0, { foldmethod = "manual", statuscolumn = "", conceallevel = 0 })
    vim.b.minianimate_disable = true
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
          return vim.bo[buf]
              and vim.bo[buf].filetype ~= "bigfile"
              and path
              and vim.fn.getfsize(path) > opts.size
              and "bigfile"
            or nil
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
