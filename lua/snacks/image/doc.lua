---@class snacks.image.doc
local M = {}

---@alias TSMatch {node:TSNode, meta:vim.treesitter.query.TSMetadata}
---@alias snacks.image.transform fun(match: snacks.image.match, ctx: snacks.image.ctx)

---@class snacks.image.Hover
---@field img snacks.image.Placement
---@field win snacks.win
---@field buf number

---@class snacks.image.ctx
---@field buf number
---@field lang string
---@field meta vim.treesitter.query.TSMetadata
---@field pos? TSMatch
---@field src? TSMatch
---@field content? TSMatch

---@class snacks.image.match
---@field id string
---@field pos snacks.image.Pos
---@field src? string
---@field content? string
---@field ext? string
---@field range? Range4

local META_EXT = "image.ext"
local META_SRC = "image.src"
local META_IGNORE = "image.ignore"
local META_LANG = "image.lang"

---@type table<string, snacks.image.transform>
M.transforms = {
  norg = function(img, ctx)
    local row, col = ctx.src.node:start()
    local line = vim.api.nvim_buf_get_lines(ctx.buf, row, row + 1, false)[1]
    img.src = line:sub(col + 1)
  end,
  typst = function(img, ctx)
    if not img.content then
      return
    end
    img.content = Snacks.picker.util.tpl(Snacks.image.config.math.typst.tpl, {
      color = Snacks.util.color("SnacksImageMath") or "#000000",
      header = M.get_header(ctx.buf),
      content = img.content,
    }, { indent = true, prefix = "$" })
  end,
  latex = function(img, ctx)
    if not img.content then
      return
    end
    local fg = Snacks.util.color("SnacksImageMath") or "#000000"
    img.ext = "math.tex"
    local content = vim.trim(img.content or "")
    content = content:gsub("^%$+`?", ""):gsub("`?%$+$", "")
    content = content:gsub("^\\[%[%(]", ""):gsub("\\[%]%)]$", "")
    if not content:find("^\\begin") then
      content = ("\\[%s\\]"):format(content)
    end
    local packages = { "xcolor" }
    vim.list_extend(packages, Snacks.image.config.math.latex.packages)
    for _, line in ipairs(vim.api.nvim_buf_get_lines(ctx.buf, 0, -1, false)) do
      if line:find("\\usepackage") then
        for _, p in ipairs(vim.split(line:match("{(.-)}") or "", ",%s*")) do
          if not vim.tbl_contains(packages, p) then
            packages[#packages + 1] = p
          end
        end
      end
    end
    table.sort(packages)
    img.content = Snacks.picker.util.tpl(Snacks.image.config.math.latex.tpl, {
      font_size = Snacks.image.config.math.latex.font_size or "large",
      packages = table.concat(packages, ", "),
      header = M.get_header(ctx.buf),
      color = fg:upper():sub(2),
      content = content,
    }, { indent = true, prefix = "$" })
  end,
}

---@diagnostic disable-next-line: invisible
M.TS_ASYNC = (vim.treesitter.languagetree or {})._async_parse ~= nil

local hover ---@type snacks.image.Hover?
local uv = vim.uv or vim.loop
local dir_cache = {} ---@type table<string, boolean>

---@param buf number
function M.get_header(buf)
  local header = {} ---@type string[]
  local in_header = false
  for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    if line:find("snacks:%s*header%s*start") then
      in_header = true
    elseif line:find("snacks:%s*header%s*end") then
      in_header = false
    elseif in_header then
      header[#header + 1] = line
    end
  end
  return table.concat(header, "\n")
end

---@param str string
function M.url_decode(str)
  return str:gsub("+", " "):gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end)
end

---@param dir string
function M.is_dir(dir)
  if dir_cache[dir] == nil then
    dir_cache[dir] = vim.fn.isdirectory(dir) == 1
  end
  return dir_cache[dir]
end

---@param buf number
---@param src string
function M.resolve(buf, src)
  src = M.url_decode(src)
  local file = svim.fs.normalize(vim.api.nvim_buf_get_name(buf))
  local s = Snacks.image.config.resolve and Snacks.image.config.resolve(file, src) or nil
  if s then
    return s
  end
  if not src:find("^%w%w+://") then
    local cwd = uv.cwd() or "."
    local checks = { [src] = true }
    for _, root in ipairs({ cwd, vim.fs.dirname(file) }) do
      checks[root .. "/" .. src] = true
      for _, dir in ipairs(Snacks.image.config.img_dirs) do
        dir = root .. "/" .. dir
        if M.is_dir(dir) then
          checks[dir .. "/" .. src] = true
        end
      end
    end
    for f in pairs(checks) do
      if vim.fn.filereadable(f) == 1 then
        src = uv.fs_realpath(f) or f
        break
      end
    end
    src = svim.fs.normalize(src)
  end
  return src
end

---@param buf number
---@param from? number
---@param to? number
function M.find(buf, from, to)
  local ok, parser = pcall(vim.treesitter.get_parser, buf)
  if not ok or not parser then
    return {}
  end
  parser:parse(from and to and { from, to } or true)
  local ret = {} ---@type snacks.image.match[]
  parser:for_each_tree(function(tstree, tree)
    if not tstree then
      return
    end
    local query = vim.treesitter.query.get(tree:lang(), "images")
    if not query then
      return
    end
    for _, match, meta in query:iter_matches(tstree:root(), buf, from and from - 1 or nil, to and to - 1 or nil) do
      if not meta[META_IGNORE] then
        ---@type snacks.image.ctx
        local ctx = {
          buf = buf,
          lang = tostring(meta[META_LANG] or meta["injection.language"] or tree:lang()),
          meta = meta,
        }
        for id, nodes in pairs(match) do
          nodes = type(nodes) == "userdata" and { nodes } or nodes
          local name = query.captures[id]
          local field = name == "image" and "pos" or name:match("^image%.(.*)$")
          if field then
            ---@diagnostic disable-next-line: assign-type-mismatch
            ctx[field] = { node = nodes[1], meta = meta[id] or {} }
          end
        end
        ret[#ret + 1] = M._img(ctx)
      end
    end
  end)
  return ret
end

---@param ctx snacks.image.ctx
function M._img(ctx)
  ctx.pos = ctx.pos or ctx.src or ctx.content
  assert(ctx.pos, "no image node")

  local range = vim.treesitter.get_range(ctx.pos.node, ctx.buf, ctx.pos.meta)
  local lines = vim.api.nvim_buf_get_lines(ctx.buf, range[1], range[4] + 1, false)
  while #lines > 0 and vim.trim(lines[#lines]) == "" do
    table.remove(lines)
  end
  ---@type snacks.image.match
  local img = {
    ext = ctx.meta[META_EXT],
    src = ctx.meta[META_SRC],
    id = ctx.pos.node:id(),
    range = { range[1] + 1, range[2], range[4] + 1, range[5] },
    pos = {
      range[1] + #lines,
      math.min(range[2], range[5]),
    },
  }
  img.pos[1] = math.min(img.pos[1], vim.api.nvim_buf_line_count(ctx.buf))
  if ctx.src then
    img.src = vim.treesitter.get_node_text(ctx.src.node, ctx.buf, { metadata = ctx.src.meta })
  end
  if ctx.content then
    img.content = vim.treesitter.get_node_text(ctx.content.node, ctx.buf, { metadata = ctx.content.meta })
  end
  assert(img.src or img.content, "no image src or content")

  local transform = M.transforms[ctx.lang]
  if transform then
    transform(img, ctx)
  end
  if img.src then
    img.src = M.resolve(ctx.buf, img.src)
  end
  if not Snacks.image.config.math.enabled and img.ext and img.ext:find("math") then
    return
  end
  if img.content and not img.src then
    local root = Snacks.image.config.cache
    vim.fn.mkdir(root, "p")
    img.src = root .. "/" .. vim.fn.sha256(img.content):sub(1, 8) .. "-content." .. (img.ext or "png")
    if vim.fn.filereadable(img.src) == 0 then
      local fd = assert(io.open(img.src, "w"), "failed to open " .. img.src)
      fd:write(img.content)
      fd:close()
    end
  end
  return img
end

function M.hover_close()
  if hover then
    hover.win:close()
    hover.img:close()
    hover = nil
  end
end

--- Get the image at the cursor (if any)
---@return string? image_src, snacks.image.Pos? image_pos
function M.at_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local imgs = M.find(vim.api.nvim_get_current_buf(), cursor[1], cursor[1] + 1)
  for _, img in ipairs(imgs) do
    local range = img.range
    if range then
      if
        (range[1] == range[3] and cursor[2] >= range[2] and cursor[2] <= range[4])
        or (range[1] ~= range[3] and cursor[1] >= range[1] and cursor[1] <= range[3])
      then
        return img.src, img.pos
      end
    end
  end
end

function M.hover()
  local current_win = vim.api.nvim_get_current_win()
  local current_buf = vim.api.nvim_get_current_buf()

  if hover and hover.win.win == current_win and hover.win:valid() then
    return
  end

  if hover and (not hover.win:valid() or hover.buf ~= current_buf or vim.fn.mode() ~= "n") then
    M.hover_close()
  end

  local src = M.at_cursor()
  if not src then
    return M.hover_close()
  end

  if hover and hover.img.img.src ~= src then
    M.hover_close()
  elseif hover then
    hover.img:update()
    return
  end

  local win = Snacks.win(Snacks.win.resolve(Snacks.image.config.doc, "snacks_image", {
    show = false,
    enter = false,
  }))
  win:open_buf()
  local updated = false
  local o = Snacks.config.merge({}, Snacks.image.config.doc, {
    on_update_pre = function()
      if hover and not updated then
        updated = true
        local loc = hover.img:state().loc
        win.opts.width = loc.width
        win.opts.height = loc.height
        win:show()
      end
    end,
    inline = false,
  })
  hover = {
    win = win,
    buf = current_buf,
    img = Snacks.image.placement.new(win.buf, src, o),
  }
  vim.api.nvim_create_autocmd({ "BufWritePost", "CursorMoved", "ModeChanged", "BufLeave" }, {
    group = vim.api.nvim_create_augroup("snacks.image.hover", { clear = true }),
    callback = function()
      if not hover then
        return true
      end
      M.hover()
      if not hover then
        return true
      end
    end,
  })
end

---@param buf number
function M.inline(buf)
  local imgs = {} ---@type table<string, snacks.image.Placement>
  return function()
    local found = {} ---@type table<string, boolean>
    for _, i in ipairs(M.find(buf)) do
      local img = imgs[i.id] ---@type snacks.image.Placement?
      if img and img.img.src ~= i.src then
        img:close()
        img = nil
      end

      if not img then
        img = Snacks.image.placement.new(
          buf,
          i.src,
          Snacks.config.merge({}, Snacks.image.config.doc, {
            pos = i.pos,
            range = i.range,
            inline = true,
          })
        )
        imgs[i.id] = img
      else
        img:update()
      end
      found[i.id] = true
    end
    for nid, img in pairs(imgs) do
      if not found[nid] then
        img:close()
        imgs[nid] = nil
      end
    end
  end
end

---@param buf number
function M.attach(buf)
  if vim.b[buf].snacks_image_attached then
    return
  end
  vim.b[buf].snacks_image_attached = true
  local inline = Snacks.image.config.doc.inline and Snacks.image.terminal.env().placeholders
  local float = Snacks.image.config.doc.float and not inline

  if not inline and not float then
    return
  end

  local group = vim.api.nvim_create_augroup("snacks.image.doc." .. buf, { clear = true })

  local update = inline and M.inline(buf) or M.hover

  if inline then
    vim.api.nvim_create_autocmd("BufWritePost", {
      group = group,
      buffer = buf,
      callback = vim.schedule_wrap(update),
    })
  else
    vim.api.nvim_create_autocmd({ "CursorMoved" }, {
      group = group,
      buffer = buf,
      callback = vim.schedule_wrap(update),
    })
  end
  vim.schedule(update)
end

return M
