local Snacks = require("snacks")

---@class snacks.statuscolumn
---@overload fun(): string
local M = setmetatable({}, {
  __call = function(t)
    return t.get()
  end,
})

M.meta = {
  desc = "Pretty status column",
  needs_setup = true,
}

---@class snacks.statuscolumn.FoldInfo
---@field start number Line number where deepest fold starts
---@field level number Fold level, when zero other fields are N/A
---@field llevel number Lowest level that starts in v:lnum
---@field lines number Number of lines from v:lnum to end of closed fold

---@type ffi.namespace*
local C

local function _ffi()
  if not C then
    local ffi = require("ffi")
    ffi.cdef([[
      typedef struct {} Error;
      typedef struct {} win_T;
      typedef struct {
        int start;  // line number where deepest fold starts
        int level;  // fold level, when zero other fields are N/A
        int llevel; // lowest level that starts in v:lnum
        int lines;  // number of lines from v:lnum to end of closed fold
      } foldinfo_T;
      foldinfo_T fold_info(win_T* wp, int lnum);
      win_T *find_window_by_handle(int Window, Error *err);
    ]])
    C = ffi.C
  end
  return C
end

-- Returns fold info for a given window and line number
---@param win number
---@param lnum number
local function fold_info(win, lnum)
  pcall(_ffi)
  if not C then
    return
  end
  local ffi = require("ffi")
  local err = ffi.new("Error")
  local wp = C.find_window_by_handle(win, err)
  if wp == nil then
    return
  end
  return C.fold_info(wp, lnum) ---@type snacks.statuscolumn.FoldInfo
end

---@alias snacks.statuscolumn.Component "mark"|"sign"|"fold"|"git"
---@alias snacks.statuscolumn.Components snacks.statuscolumn.Component[]|fun(win:number,buf:number,lnum:number):snacks.statuscolumn.Component[]
---@alias snacks.statuscolumn.Wanted table<snacks.statuscolumn.Component, boolean>

---@class snacks.statuscolumn.Config
---@field left snacks.statuscolumn.Components
---@field right snacks.statuscolumn.Components
---@field enabled? boolean
local defaults = {
  left = { "mark", "sign" }, -- priority of signs on the left (high to low)
  right = { "fold", "git" }, -- priority of signs on the right (high to low)
  folds = {
    open = false, -- show open fold icons
    git_hl = false, -- use Git Signs hl for fold icons
  },
  git = {
    -- patterns to match Git signs
    patterns = { "GitSign", "MiniDiffSign" },
  },
  refresh = 50, -- refresh at most every 50ms
}

local config = Snacks.config.get("statuscolumn", defaults)

---@private
---@alias snacks.statuscolumn.Sign.type "mark"|"sign"|"fold"|"git"
---@alias snacks.statuscolumn.Sign {name:string, text:string, texthl:string, priority:number, type:snacks.statuscolumn.Sign.type}

-- Cache for signs per buffer and line
---@type table<number,table<number,snacks.statuscolumn.Sign[]>>
local sign_cache = {}
local cache = {} ---@type table<string,string>
local icon_cache = {} ---@type table<string,string>

local did_setup = false

---@private
function M.setup()
  if did_setup then
    return
  end
  did_setup = true
  Snacks.util.set_hl({
    Mark = "DiagnosticHint",
  }, { prefix = "SnacksStatusColumn", default = true })
  local timer = assert((vim.uv or vim.loop).new_timer())
  timer:start(config.refresh, config.refresh, function()
    sign_cache = {}
    cache = {}
  end)
end

---@private
---@param name string
function M.is_git_sign(name)
  for _, pattern in ipairs(config.git.patterns) do
    if name:find(pattern) then
      return true
    end
  end
end

-- Returns a list of regular and extmark signs sorted by priority (low to high)
---@private
---@param wanted snacks.statuscolumn.Wanted
---@return table<number, snacks.statuscolumn.Sign[]>
---@param buf number
function M.buf_signs(buf, wanted)
  -- Get regular signs
  ---@type table<number, snacks.statuscolumn.Sign[]>
  local signs = {}

  if wanted.git or wanted.sign then
    if vim.fn.has("nvim-0.10") == 0 then
      -- Only needed for Neovim <0.10
      -- Newer versions include legacy signs in nvim_buf_get_extmarks
      for _, sign in ipairs(vim.fn.sign_getplaced(buf, { group = "*" })[1].signs) do
        local ret = vim.fn.sign_getdefined(sign.name)[1] --[[@as snacks.statuscolumn.Sign]]
        if ret then
          ret.priority = sign.priority
          ret.type = M.is_git_sign(sign.name) and "git" or "sign"
          signs[sign.lnum] = signs[sign.lnum] or {}
          if wanted[ret.type] then
            table.insert(signs[sign.lnum], ret)
          end
        end
      end
    end

    -- Get extmark signs
    local extmarks = vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true, type = "sign" })
    for _, extmark in pairs(extmarks) do
      local lnum = extmark[2] + 1
      signs[lnum] = signs[lnum] or {}
      local name = extmark[4].sign_hl_group or extmark[4].sign_name or ""
      local ret = {
        name = name,
        type = M.is_git_sign(name) and "git" or "sign",
        text = extmark[4].sign_text,
        texthl = extmark[4].sign_hl_group,
        priority = extmark[4].priority,
      }
      if wanted[ret.type] then
        table.insert(signs[lnum], ret)
      end
    end
  end

  -- Add marks
  if wanted.mark then
    local marks = vim.fn.getmarklist(buf)
    vim.list_extend(marks, vim.fn.getmarklist())
    for _, mark in ipairs(marks) do
      if mark.pos[1] == buf and mark.mark:match("[a-zA-Z]") then
        local lnum = mark.pos[2]
        signs[lnum] = signs[lnum] or {}
        table.insert(signs[lnum], { text = mark.mark:sub(2), texthl = "SnacksStatusColumnMark", type = "mark" })
      end
    end
  end

  return signs
end

-- Returns a list of regular and extmark signs sorted by priority (high to low)
---@private
---@param win number
---@param buf number
---@param lnum number
---@param wanted snacks.statuscolumn.Wanted
---@return snacks.statuscolumn.Sign[]
function M.line_signs(win, buf, lnum, wanted)
  local buf_signs = sign_cache[buf]
  if not buf_signs then
    buf_signs = M.buf_signs(buf, wanted)
    sign_cache[buf] = buf_signs
  end
  local signs = buf_signs[lnum] or {}

  -- Get fold signs
  if wanted.fold then
    local info = fold_info(win, lnum)
    if info and info.level > 0 then
      if info.lines > 0 then
        signs[#signs + 1] = { text = vim.opt.fillchars:get().foldclose or "", texthl = "Folded", type = "fold" }
      elseif config.folds.open and info.start == lnum then
        signs[#signs + 1] = { text = vim.opt.fillchars:get().foldopen or "", type = "fold" }
      end
    end
  end

  -- Sort by priority
  table.sort(signs, function(a, b)
    return (a.priority or 0) > (b.priority or 0)
  end)
  return signs
end

---@private
---@param sign? snacks.statuscolumn.Sign
function M.icon(sign)
  if not sign then
    return "  "
  end
  local key = (sign.text or "") .. (sign.texthl or "")
  if icon_cache[key] then
    return icon_cache[key]
  end
  local text = vim.fn.strcharpart(sign.text or "", 0, 2) ---@type string
  text = text .. string.rep(" ", 2 - vim.fn.strchars(text))
  icon_cache[key] = sign.texthl and ("%#" .. sign.texthl .. "#" .. text .. "%*") or text
  return icon_cache[key]
end

---@return string
function M._get()
  if not did_setup then
    M.setup()
  end
  local win = vim.g.statusline_winid
  local nu = vim.wo[win].number
  local rnu = vim.wo[win].relativenumber
  local show_signs = vim.v.virtnum == 0 and vim.wo[win].signcolumn ~= "no"
  local show_folds = vim.v.virtnum == 0 and vim.wo[win].foldcolumn ~= "0"
  local buf = vim.api.nvim_win_get_buf(win)
  local left_c = type(config.left) == "function" and config.left(win, buf, vim.v.lnum) or config.left --[[@as snacks.statuscolumn.Component[] ]]
  local right_c = type(config.right) == "function" and config.right(win, buf, vim.v.lnum) or config.right --[[@as snacks.statuscolumn.Component[] ]]

  ---@type snacks.statuscolumn.Wanted
  local wanted = { sign = show_signs }
  for _, c in ipairs(left_c) do
    wanted[c] = wanted[c] ~= false
  end
  for _, c in ipairs(right_c) do
    wanted[c] = wanted[c] ~= false
  end

  local components = { "", "", "" } -- left, middle, right
  if not (show_signs or nu or rnu) then
    return ""
  end

  if (nu or rnu) and vim.v.virtnum == 0 then
    local num ---@type number
    if rnu and nu and vim.v.relnum == 0 then
      num = vim.v.lnum
    elseif rnu then
      num = vim.v.relnum
    else
      num = vim.v.lnum
    end
    components[2] = "%=" .. num .. " "
  end

  if show_signs or show_folds then
    local signs = M.line_signs(win, buf, vim.v.lnum, wanted)

    if #signs > 0 then
      local signs_by_type = {} ---@type table<snacks.statuscolumn.Sign.type,snacks.statuscolumn.Sign>
      for _, s in ipairs(signs) do
        signs_by_type[s.type] = signs_by_type[s.type] or s
      end

      ---@param types snacks.statuscolumn.Sign.type[]
      local function find(types)
        for _, t in ipairs(types) do
          if signs_by_type[t] then
            return signs_by_type[t]
          end
        end
      end

      local left, right = find(left_c), find(right_c)

      if config.folds.git_hl then
        local git = signs_by_type.git
        if git and left and left.type == "fold" then
          left.texthl = git.texthl
        end
        if git and right and right.type == "fold" then
          right.texthl = git.texthl
        end
      end
      components[1] = left and M.icon(left) or "  " -- left
      components[3] = right and M.icon(right) or "  " -- right
    else
      components[1] = "  "
      components[3] = "  "
    end
  end
  components[1] = vim.b[buf].snacks_statuscolumn_left ~= false and components[1] or ""
  components[3] = vim.b[buf].snacks_statuscolumn_right ~= false and components[3] or ""

  local ret = table.concat(components, "")
  return "%@v:lua.require'snacks.statuscolumn'.click_fold@" .. ret .. "%T"
end

function M.get()
  local win = vim.g.statusline_winid
  local buf = vim.api.nvim_win_get_buf(win)
  local key = ("%d:%d:%d:%d:%d"):format(win, buf, vim.v.lnum, vim.v.virtnum ~= 0 and 1 or 0, vim.v.relnum)
  if cache[key] then
    return cache[key]
  end
  local ok, ret = pcall(M._get)
  if ok then
    cache[key] = ret
    return ret
  end
  return ""
end

---@private
function M.health()
  local ready = vim.o.statuscolumn:find("snacks.statuscolumn", 1, true)
  if config.enabled and not ready then
    Snacks.health.warn(("is not configured\n- `vim.o.statuscolumn = %q`"):format(vim.o.statuscolumn))
  elseif not config.enabled and ready then
    Snacks.health.ok(("is manually configured\n- `vim.o.statuscolumn = %q`"):format(vim.o.statuscolumn))
  end
end

function M.click_fold()
  local pos = vim.fn.getmousepos()
  vim.api.nvim_win_set_cursor(pos.winid, { pos.line, 1 })
  vim.api.nvim_win_call(pos.winid, function()
    if vim.fn.foldlevel(pos.line) > 0 then
      vim.cmd("normal! za")
    end
  end)
end

return M
