---@class snacks.image.inline
---@field buf number
---@field imgs table<number, snacks.image.Placement>
---@field idx table<number, snacks.image.Placement>
local M = {}
M.__index = M

function M.new(buf)
  local self = setmetatable({}, M)
  self.buf = buf
  self.imgs = {}
  self.idx = {}
  local group = vim.api.nvim_create_augroup("snacks.image.inline." .. buf, { clear = true })

  local update = Snacks.util.debounce(function()
    self:update()
  end, { ms = 100 })

  vim.api.nvim_create_autocmd({ "BufWritePost", "WinScrolled", "BufWinEnter" }, {
    group = group,
    buffer = buf,
    callback = vim.schedule_wrap(update),
  })
  vim.api.nvim_create_autocmd({ "ModeChanged", "CursorMoved" }, {
    group = group,
    buffer = buf,
    callback = function(ev)
      if ev.buf == self.buf and ev.buf == vim.api.nvim_get_current_buf() then
        self:conceal()
      end
    end,
  })
  vim.api.nvim_buf_attach(buf, false, {
    on_lines = update,
  })
  vim.schedule(update)
  return self
end

function M:conceal()
  local mode = vim.fn.mode():sub(1, 1):lower() ---@type string
  for _, img in pairs(self.imgs) do
    img:show()
  end
  if vim.wo.concealcursor:find(mode) then
    return
  end
  local from, to = vim.fn.line("v"), vim.fn.line(".")
  from, to = math.min(from, to), math.max(from, to)
  local hide = self:get(from, to)
  for _, img in pairs(hide) do
    if img.opts.conceal then
      img:hide()
    end
  end
end

function M:visible()
  local ret = {} ---@type table<number, snacks.image.Placement>
  for _, win in ipairs(vim.fn.win_findbuf(self.buf)) do
    local info = vim.fn.getwininfo(win)[1]
    for k, v in pairs(self:get(math.max(info.topline - 1, 1), info.botline)) do
      ret[k] = v
    end
  end
  return ret
end

---@param from number 1-indexed inclusive
---@param to number 1-indexed inclusive
function M:get(from, to)
  local ret = {} ---@type table<number, snacks.image.Placement>
  local marks = vim.api.nvim_buf_get_extmarks(self.buf, Snacks.image.placement.ns, { from - 1, 0 }, { to, -1 }, {
    overlap = true,
    hl_name = false,
  })
  for _, m in ipairs(marks) do
    local p = self.idx[m[1]] ---@type snacks.image.Placement?
    if p and not self.imgs[p.id] then
      self.idx[m[1]] = nil
      p = nil
    end
    if p then
      ret[p.id] = p
    end
  end
  return ret
end

function M:update()
  local conceal = Snacks.image.config.doc.conceal
  conceal = type(conceal) ~= "function" and function()
    return conceal
  end or conceal
  Snacks.image.doc.find_visible(self.buf, function(imgs)
    local visible = self:visible()
    local stats = { new = 0, del = 0, update = 0 }
    for _, i in ipairs(imgs) do
      local img ---@type snacks.image.Placement?
      for v, o in pairs(visible) do
        if o.img.src == i.src then
          img = o
          visible[v] = nil
          break
        end
      end
      if not img then
        stats.new = stats.new + 1
        img = Snacks.image.placement.new(
          self.buf,
          i.src,
          Snacks.config.merge({}, Snacks.image.config.doc, {
            pos = i.pos,
            range = i.range,
            inline = true,
            conceal = conceal(i.lang, i.type),
            type = i.type,
            ---@param p snacks.image.Placement
            on_update = function(p)
              for _, eid in ipairs(p.eids) do
                self.idx[eid] = p
              end
            end,
          })
        )
        for _, eid in ipairs(img.eids) do
          self.idx[eid] = img
        end
        self.imgs[img.id] = img
      else
        stats.update = stats.update + 1
        img.opts.pos = i.pos
        img.opts.range = i.range
        img:update()
      end
    end
    for _, img in pairs(visible) do
      stats.del = stats.del + 1
      img:close()
      self.imgs[img.id] = nil
    end
    for k, v in pairs(stats) do
      stats[k] = v > 0 and v or nil
    end
    -- Snacks.notify(
    --   vim.inspect({ all = vim.tbl_count(self.imgs), stats = stats }),
    --   { ft = "lua", id = "snacks.image.inline" }
    -- )
  end)
end

return M
