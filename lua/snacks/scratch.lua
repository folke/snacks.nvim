local uv = vim.uv or vim.loop

---@class snacks.scratch
---@overload fun(opts?: snacks.scratch.Config): snacks.win
local M = setmetatable({}, {
  __call = function(M, ...)
    return M.open(...)
  end,
})

M.meta = {
  desc = "Scratch buffers with a persistent file",
}

---@class snacks.scratch.File
---@field file string full path to the scratch buffer
---@field stat uv.fs_stat.result File stat result
---@field name string name of the scratch buffer
---@field ft string file type
---@field icon? string icon for the file type
---@field cwd? string current working directory
---@field branch? string Git branch
---@field count? number vim.v.count1 used to open the buffer

---@class snacks.scratch.Config
---@field win? snacks.win.Config scratch window
---@field template? string template for new buffers
---@field file? string scratch file path. You probably don't need to set this.
---@field ft? string|fun():string the filetype of the scratch buffer
local defaults = {
  name = "Scratch",
  ft = function()
    if vim.bo.buftype == "" and vim.bo.filetype ~= "" then
      return vim.bo.filetype
    end
    return "markdown"
  end,
  ---@type string|string[]?
  icon = nil, -- `icon|{icon, icon_hl}`. defaults to the filetype icon
  root = vim.fn.stdpath("data") .. "/scratch",
  autowrite = true, -- automatically write when the buffer is hidden
  -- unique key for the scratch file is based on:
  -- * name
  -- * ft
  -- * vim.v.count1 (useful for keymaps)
  -- * cwd (optional)
  -- * branch (optional)
  filekey = {
    cwd = true, -- use current working directory
    branch = true, -- use current branch name
    count = true, -- use vim.v.count1
  },
  win = { style = "scratch" },
  ---@type table<string, snacks.win.Config>
  win_by_ft = {
    lua = {
      keys = {
        ["source"] = {
          "<cr>",
          function(self)
            local name = "scratch." .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(self.buf), ":e")
            Snacks.debug.run({ buf = self.buf, name = name })
          end,
          desc = "Source buffer",
          mode = { "n", "x" },
        },
      },
    },
  },
}

Snacks.util.set_hl({
  Title = "FloatTitle",
}, { prefix = "SnacksScratch", default = true })

Snacks.config.style("scratch", {
  width = 100,
  height = 30,
  bo = { buftype = "", buflisted = false, bufhidden = "hide", swapfile = false },
  minimal = false,
  noautocmd = false,
  -- position = "right",
  zindex = 20,
  wo = { winhighlight = "NormalFloat:Normal" },
  footer_keys = true,
  border = true,
})

--- Return a list of scratch buffers sorted by mtime.
---@return snacks.scratch.File[]
function M.list()
  local root = Snacks.config.get("scratch", defaults).root
  ---@type snacks.scratch.File[]
  local ret = {}
  for file, t in vim.fs.dir(root) do
    if t == "file" then
      local decoded = Snacks.util.file_decode(file)
      local count, icon, name, cwd, branch, ft = decoded:match("^(%d*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)%.([^|]*)$")
      if count and icon and name and cwd and branch and ft then
        file = svim.fs.normalize(root .. "/" .. file)
        table.insert(ret, {
          file = file,
          stat = uv.fs_stat(file),
          count = count ~= "" and tonumber(count) or nil,
          icon = icon ~= "" and icon or nil,
          name = name,
          cwd = cwd ~= "" and cwd or nil,
          branch = branch ~= "" and branch or nil,
          ft = ft,
        })
      end
    end
  end
  table.sort(ret, function(a, b)
    return a.stat.mtime.sec > b.stat.mtime.sec
  end)
  return ret
end

--- Select a scratch buffer from a list of scratch buffers.
function M.select()
  local widths = { 0, 0, 0, 0 }
  local items = M.list()
  for _, item in ipairs(items) do
    item.icon = item.icon or Snacks.util.icon(item.ft, "filetype")
    item.branch = item.branch and ("branch:%s"):format(item.branch) or ""
    item.cwd = item.cwd and vim.fn.fnamemodify(item.cwd, ":p:~") or ""
    widths[1] = math.max(widths[1], vim.api.nvim_strwidth(item.cwd))
    widths[2] = math.max(widths[2], vim.api.nvim_strwidth(item.icon))
    widths[3] = math.max(widths[3], vim.api.nvim_strwidth(item.name))
    widths[4] = math.max(widths[4], vim.api.nvim_strwidth(item.branch))
  end
  vim.ui.select(items, {
    prompt = "Select Scratch Buffer",
    ---@param item snacks.scratch.File
    format_item = function(item)
      local parts = { item.cwd, item.icon, item.name, item.branch }
      for i, part in ipairs(parts) do
        parts[i] = part .. string.rep(" ", widths[i] - vim.api.nvim_strwidth(part))
      end
      return table.concat(parts, " ")
    end,
  }, function(selected)
    if selected then
      M.open({ icon = selected.icon, file = selected.file, name = selected.name, ft = selected.ft })
    end
  end)
end

--- Open a scratch buffer with the given options.
--- If a window is already open with the same buffer,
--- it will be closed instead.
---@param opts? snacks.scratch.Config
function M.open(opts)
  opts = Snacks.config.get("scratch", defaults, opts)
  local ft = "markdown"
  if type(opts.ft) == "function" then
    ft = opts.ft()
  elseif type(opts.ft) == "string" then
    ft = opts.ft --[[@as string]]
  end

  opts.win = Snacks.win.resolve("scratch", opts.win_by_ft[ft], opts.win, { show = false })
  opts.win.bo = opts.win.bo or {}
  opts.win.bo.filetype = ft

  local file = opts.file
  if not file then
    local branch = ""
    if opts.filekey.branch and uv.fs_stat(".git") then
      local ret = vim.fn.systemlist("git branch --show-current")[1]
      if vim.v.shell_error == 0 then
        branch = ret or "" -- fallback for detached head (ret is nil then)
      end
    end

    local filekey = {
      opts.filekey.count and tostring(vim.v.count1) or "",
      (type(opts.icon) == "table" and opts.icon[1]) or opts.icon or "",
      opts.name:gsub("|", " "),
      opts.filekey.cwd and svim.fs.normalize(assert(uv.cwd())) or "",
      branch,
    }

    vim.fn.mkdir(opts.root, "p")
    local fname = Snacks.util.file_encode(table.concat(filekey, "|") .. "." .. ft)
    file = opts.root .. "/" .. fname
  end
  file = svim.fs.normalize(file)

  local icon, icon_hl = unpack(type(opts.icon) == "table" and opts.icon or { opts.icon, nil })
  ---@cast icon string
  if not icon then
    icon, icon_hl = Snacks.util.icon(ft, "filetype")
  end
  opts.win.title = {
    { " " },
    { icon .. string.rep(" ", 2 - vim.api.nvim_strwidth(icon)), icon_hl },
    { " " },
    { opts.name .. (vim.v.count1 > 1 and " " .. vim.v.count1 or "") },
    { " " },
  }
  for _, t in ipairs(opts.win.title) do
    t[2] = t[2] or "SnacksScratchTitle"
  end

  local is_new = not uv.fs_stat(file)
  local buf = vim.fn.bufadd(file)

  local closed = false
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(win) == buf then
      vim.schedule(function()
        vim.api.nvim_win_call(win, function()
          vim.cmd([[close]])
        end)
      end)
      closed = true
    end
  end
  if closed then
    return
  end
  is_new = is_new
    and vim.api.nvim_buf_line_count(buf) == 0
    and #(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or "") == 0

  if not vim.api.nvim_buf_is_loaded(buf) then
    vim.fn.bufload(buf)
  end

  if opts.template then
    local function reset()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(opts.template, "\n"))
    end
    opts.win.keys = opts.win.keys or {}
    opts.win.keys.reset = { "R", reset, desc = "Reset buffer" }
    if is_new then
      reset()
    end
  end

  opts.win.buf = buf
  if opts.autowrite then
    vim.api.nvim_create_autocmd("BufHidden", {
      group = vim.api.nvim_create_augroup("snacks_scratch_autowrite_" .. buf, { clear = true }),
      buffer = buf,
      callback = function(ev)
        vim.api.nvim_buf_call(ev.buf, function()
          vim.cmd("silent! write")
          vim.bo[ev.buf].buflisted = false
        end)
      end,
    })
  end
  return Snacks.win(opts.win):show()
end

return M
