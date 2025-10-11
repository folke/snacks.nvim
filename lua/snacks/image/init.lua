---@class snacks.image
---@field terminal snacks.image.terminal
---@field image snacks.Image
---@field placement snacks.image.Placement
---@field util snacks.image.util
---@field buf snacks.image.buf
---@field doc snacks.image.doc
---@field convert snacks.image.convert
---@field inline snacks.image.inline
local M = setmetatable({}, {
  ---@param M snacks.image
  __index = function(M, k)
    if vim.tbl_contains({ "terminal", "image", "placement", "util", "doc", "buf", "convert", "inline" }, k) then
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
---@alias snacks.image.Type "image"|"math"|"chart"

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
---@field convert? snacks.image.convert.Config
local defaults = {
  formats = {
    "png",
    "jpg",
    "jpeg",
    "gif",
    "bmp",
    "webp",
    "tiff",
    "heic",
    "avif",
    "mp4",
    "mov",
    "avi",
    "mkv",
    "webm",
    "pdf",
  },
  force = false, -- try displaying the image, even if the terminal does not support it
  doc = {
    -- enable image viewer for documents
    -- a treesitter parser must be available for the enabled languages.
    enabled = true,
    -- render the image inline in the buffer
    -- if your env doesn't support unicode placeholders, this will be disabled
    -- takes precedence over `opts.float` on supported terminals
    inline = true,
    -- render the image in a floating window
    -- only used if `opts.inline` is disabled
    float = true,
    max_width = 80,
    max_height = 40,
    -- enable the floating window to follow cursor
    follow_cursor = false,
    -- Set to `true`, to conceal the image text when rendering inline.
    -- (experimental)
    ---@param lang string tree-sitter language
    ---@param type snacks.image.Type image type
    conceal = function(lang, type)
      -- only conceal math expressions
      return type == "math"
    end,
  },
  img_dirs = { "img", "images", "assets", "static", "public", "media", "attachments" },
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
  cache = vim.fn.stdpath("cache") .. "/snacks/image",
  debug = {
    request = false,
    convert = false,
    placement = false,
  },
  env = {},
  -- icons used to show where an inline image is located that is
  -- rendered below the text.
  icons = {
    math = "󰪚 ",
    chart = "󰄧 ",
    image = " ",
  },
  ---@class snacks.image.convert.Config
  convert = {
    notify = true, -- show a notification on error
    ---@type snacks.image.args
    mermaid = function()
      local theme = vim.o.background == "light" and "neutral" or "dark"
      return { "-i", "{src}", "-o", "{file}", "-b", "transparent", "-t", theme, "-s", "{scale}" }
    end,
    ---@type table<string,snacks.image.args>
    magick = {
      default = { "{src}[0]", "-scale", "1920x1080>" }, -- default for raster images
      vector = { "-density", 192, "{src}[0]" }, -- used by vector images like svg
      math = { "-density", 192, "{src}[0]", "-trim" },
      pdf = { "-density", 192, "{src}[0]", "-background", "white", "-alpha", "remove", "-trim" },
    },
  },
  math = {
    enabled = true, -- enable math expression rendering
    -- in the templates below, `${header}` comes from any section in your document,
    -- between a start/end header comment. Comment syntax is language-specific.
    -- * start comment: `// snacks: header start`
    -- * end comment:   `// snacks: header end`
    typst = {
      tpl = [[
        #set page(width: auto, height: auto, margin: (x: 2pt, y: 2pt))
        #show math.equation.where(block: false): set text(top-edge: "bounds", bottom-edge: "bounds")
        #set text(size: 12pt, fill: rgb("${color}"))
        ${header}
        ${content}]],
    },
    latex = {
      font_size = "Large", -- see https://www.sascha-frank.com/latex-font-size.html
      -- for latex documents, the doc packages are included automatically,
      -- but you can add more packages here. Useful for markdown documents.
      packages = { "amsmath", "amssymb", "amsfonts", "amscd", "mathtools" },
      tpl = [[
        \documentclass[preview,border=0pt,varwidth,12pt]{standalone}
        \usepackage{${packages}}
        \begin{document}
        ${header}
        { \${font_size} \selectfont
          \color[HTML]{${color}}
        ${content}}
        \end{document}]],
    },
  },
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

Snacks.util.set_hl({
  Spinner = "Special",
  Anchor = "Special",
  Loading = "NonText",
  Math = { fg = Snacks.util.color({ "@markup.math.latex", "Special", "Normal" }) },
}, { prefix = "SnacksImage", default = true })

---@class snacks.image.Opts
---@field pos? snacks.image.Pos (row, col) (1,0)-indexed. defaults to the top-left corner
---@field range? Range4
---@field conceal? boolean
---@field inline? boolean render the image inline in the buffer
---@field width? number
---@field min_width? number
---@field max_width? number
---@field height? number
---@field min_height? number
---@field max_height? number
---@field follow_cursor? boolean
---@field on_update? fun(placement: snacks.image.Placement)
---@field on_update_pre? fun(placement: snacks.image.Placement)
---@field type? snacks.image.Type
---@field auto_resize? boolean

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

---@return string[]
function M.langs()
  local queries = vim.api.nvim_get_runtime_file("queries/*/images.scm", true)
  return vim.tbl_map(function(q)
    return q:match("queries/(.-)/images%.scm")
  end, queries)
end

---@private
---@param ev? vim.api.keyset.create_autocmd.callback_args
function M.setup(ev)
  if did_setup then
    return
  end
  did_setup = true
  local group = vim.api.nvim_create_augroup("snacks.image", { clear = true })

  vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, {
    group = group,
    callback = function(e)
      vim.schedule(function()
        Snacks.image.placement.clean(e.buf)
      end)
    end,
  })
  vim.api.nvim_create_autocmd({ "ExitPre" }, {
    group = group,
    once = true,
    callback = function()
      Snacks.image.placement.clean()
    end,
  })

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
    local langs = M.langs()
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      callback = function(e)
        local ft = vim.bo[e.buf].filetype
        local lang = vim.treesitter.language.get_lang(ft)
        if vim.tbl_contains(langs, lang) then
          vim.schedule(function()
            if vim.api.nvim_buf_is_valid(e.buf) then
              M.doc.attach(e.buf)
            end
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
  local is_win = jit.os:find("Windows")
  if not Snacks.health.have_tool({ "magick", not is_win and "convert" or nil }) then
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

  local langs, _, missing = Snacks.health.has_lang(M.langs())
  if missing > 0 then
    Snacks.health.warn("Image rendering in docs with missing treesitter parsers won't work")
  end

  if Snacks.health.have_tool("gs") then
    Snacks.health.ok("PDF files are supported")
  else
    Snacks.health.warn("`gs` is required to render PDF files")
  end

  if Snacks.health.have_tool({ "tectonic", "pdflatex" }) then
    if langs.latex then
      Snacks.health.ok("LaTeX math equations are supported")
    else
      Snacks.health.warn("The `latex` treesitter parser is required to render LaTeX math expressions")
    end
  else
    Snacks.health.warn("`tectonic` or `pdflatex` is required to render LaTeX math expressions")
  end

  if Snacks.health.have_tool("mmdc") then
    Snacks.health.ok("Mermaid diagrams are supported")
  else
    Snacks.health.warn("`mmdc` is required to render Mermaid diagrams")
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
