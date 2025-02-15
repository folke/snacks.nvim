---@class snacks.image
---@field terminal snacks.image.terminal
---@field image snacks.Image
---@field placement snacks.image.Placement
---@field util snacks.image.util
---@field buf snacks.image.buf
---@field doc snacks.image.doc
local M = setmetatable({}, {
  ---@param M snacks.image
  __index = function(M, k)
    if vim.tbl_contains({ "terminal", "image", "placement", "util", "doc", "buf" }, k) then
      M[k] = require("snacks.image." .. k)
    end
    return rawget(M, k)
  end,
})

M.meta = {
  desc = "Image viewer using Kitty Graphics Protocol, supported by `kitty`, `wezterm` and `ghostty`",
  needs_setup = true,
}

---@alias snacks.image.Size {width: number, height: number}
---@alias snacks.image.Pos {[1]: number, [2]: number}
---@alias snacks.image.Loc snacks.image.Pos|snacks.image.Size|{zindex?: number}

---@class snacks.image.Env
---@field name string
---@field env table<string, string|true>
---@field supported? boolean default: false
---@field placeholders? boolean default: false
---@field setup? fun(): boolean?
---@field transform? fun(data: string): string
---@field detected? boolean
---@field remote? boolean this is a remote client, so full transfer of the image data is required

---@class snacks.image.Config
---@field enabled? boolean enable image viewer
---@field wo? vim.wo|{} options for windows showing the image
---@field bo? vim.bo|{} options for the image buffer
---@field formats? string[]
--- Resolves a reference to an image with src in a file (currently markdown only).
--- Return the absolute path or url to the image.
--- When `nil`, the path is resolved relative to the file.
---@field resolve? fun(file: string, src: string): string?
local defaults = {
  formats = { "png", "jpg", "jpeg", "gif", "bmp", "webp", "tiff", "heic", "avif", "mp4", "mov", "avi", "mkv", "webm" },
  force = false, -- try displaying the image, even if the terminal does not support it
  doc = {
    -- enable image viewer for documents
    -- a treesitter parser must be available for the enabled languages.
    -- supported language injections: markdown, html
    enabled = true,
    lang = { "markdown", "html", "norg" },
    -- render the image inline in the buffer
    -- if your env doesn't support unicode placeholders, this will be disabled
    -- takes precedence over `opts.float` on supported terminals
    inline = true,
    -- render the image in a floating window
    -- only used if `opts.inline` is disabled
    float = true,
    max_width = 80,
    max_height = 40,
  },
  -- window options applied to windows displaying image buffers
  -- an image buffer is a buffer with `filetype=image`
  wo = {
    wrap = false,
    number = false,
    relativenumber = false,
    cursorcolumn = false,
    signcolumn = "no",
    foldcolumn = "0",
    list = false,
    spell = false,
    statuscolumn = "",
  },
  debug = false,
  env = {},
}
M.config = Snacks.config.get("image", defaults)

Snacks.config.style("snacks_image", {
  relative = "cursor",
  border = "rounded",
  focusable = false,
  backdrop = false,
  row = 1,
  col = 1,
  -- width/height are automatically set by the image size unless specified below
})

---@class snacks.image.Opts
---@field pos? snacks.image.Pos (row, col) (1,0)-indexed. defaults to the top-left corner
---@field inline? boolean render the image inline in the buffer
---@field width? number
---@field min_width? number
---@field max_width? number
---@field height? number
---@field min_height? number
---@field max_height? number
---@field on_update? fun(placement: snacks.image.Placement)
---@field on_update_pre? fun(placement: snacks.image.Placement)

local did_setup = false

--- Check if the file format is supported
---@param file string
function M.supports_file(file)
  return vim.tbl_contains(M.config.formats or {}, vim.fn.fnamemodify(file, ":e"):lower())
end

--- Check if the file format is supported and the terminal supports the kitty graphics protocol
---@param file string
function M.supports(file)
  return M.supports_file(file) and M.supports_terminal()
end

-- Check if the terminal supports the kitty graphics protocol
function M.supports_terminal()
  return M.terminal.env().supported or M.config.force or false
end

--- Show the image at the cursor in a floating window
function M.hover()
  M.doc.hover()
end

---@private
---@param ev? vim.api.keyset.create_autocmd.callback_args
function M.setup(ev)
  if did_setup then
    return
  end
  did_setup = true
  local group = vim.api.nvim_create_augroup("snacks.image", { clear = true })

  if M.config.formats and #M.config.formats > 0 then
    vim.api.nvim_create_autocmd("BufReadCmd", {
      pattern = "*." .. table.concat(M.config.formats, ",*."),
      group = group,
      callback = function(e)
        M.buf.attach(e.buf)
      end,
    })
    -- prevent altering the original image file
    vim.api.nvim_create_autocmd("BufWriteCmd", {
      pattern = "*." .. table.concat(M.config.formats, ",*."),
      group = group,
      callback = function(e)
        -- vim.api.nvim_exec_autocmds("BufWritePre", { buffer = e.buf })
        vim.bo[e.buf].modified = false
        -- vim.api.nvim_exec_autocmds("BufWritePost", { buffer = e.buf })
      end,
    })
  end
  if M.config.enabled and M.config.doc.enabled then
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      callback = function(e)
        local ft = vim.bo[e.buf].filetype
        local lang = vim.treesitter.language.get_lang(ft)
        if vim.tbl_contains(M.config.doc.lang, lang) then
          vim.schedule(function()
            M.doc.attach(e.buf)
          end)
        end
      end,
    })
  end
  if ev and ev.event == "BufReadCmd" then
    M.buf.attach(ev.buf)
  end
end

---@private
function M.health()
  Snacks.health.have_tool({ "kitty", "wezterm", "ghostty" })
  if not Snacks.health.have_tool("magick") then
    Snacks.health.error("`magick` is required to convert images. Only PNG files will be displayed.")
  end
  local env = M.terminal.env()
  for _, e in ipairs(M.terminal.envs()) do
    if e.detected then
      if e.supported == false then
        Snacks.health.error("`" .. e.name .. "` is not supported")
      else
        Snacks.health.ok("`" .. e.name .. "` detected and supported")
        if e.placeholders == false then
          Snacks.health.warn("`" .. e.name .. "` does not support placeholders. Fallback rendering will be used")
          Snacks.health.warn("Inline images are disabled")
        elseif e.placeholders == true then
          Snacks.health.ok("`" .. e.name .. "` supports unicode placeholders")
          Snacks.health.ok("Inline images are available")
        end
      end
    end
  end
  local size = M.terminal.size()
  Snacks.health.ok(
    ("Terminal Dimensions:\n- {size}: `%d` x `%d` pixels\n- {scale}: `%.2f`\n- {cell}: `%d` x `%d` pixels"):format(
      size.width,
      size.height,
      size.scale,
      size.cell_width,
      size.cell_height
    )
  )

  M.doc.queries()
  for lang, q in pairs(M.doc._queries) do
    if q.query then
      Snacks.health.ok("Images rendering for `" .. lang .. "` is available")
    else
      Snacks.health.warn("Images rendering for `" .. lang .. "` is not available.\nMissing treesitter parser.")
    end
  end
  if env.supported then
    Snacks.health.ok("your terminal supports the kitty graphics protocol")
  elseif M.config.force then
    Snacks.health.warn("image viewer is enabled with `opts.force = true`. Use at your own risk")
  else
    Snacks.health.error("your terminal does not support the kitty graphics protocol")
    Snacks.health.info("supported terminals: `kitty`, `wezterm`, `ghostty`")
  end
end

return M
