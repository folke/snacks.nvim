---@class snacks.profiler.loc
---@field vim_runtime string
---@field user_runtime string
---@field user_config string
local M = {}

local fun_cache = {} ---@type table<function, snacks.profiler.Loc|false>
local norm_cache = {} ---@type table<string, table<number,snacks.profiler.Loc>>
local path_cache = {} ---@type table<string, string>
local ts_cache = {} ---@type table<string, table<string, snacks.profiler.Loc>>
local ts_query ---@type vim.treesitter.Query?

-- add and normalize locations
function M.load()
  local opts = Snacks.profiler.config
  M.vim_runtime = M.realpath(vim.env.VIMRUNTIME)
  M.user_runtime = M.realpath(opts.runtime or M.vim_runtime)
  M.user_config = M.realpath(vim.fn.stdpath("config") .. "")

  Snacks.profiler.tracer.walk(function(entry)
    entry.def = M.loc(entry)
    entry.ref = entry.ref and M.norm(entry.ref) or nil
  end)
end

-- Get the location at the cursor
function M.current()
  local cursor = vim.api.nvim_win_get_cursor(0)
  return M.norm({ file = vim.api.nvim_buf_get_name(0), line = cursor[1] })
end

--- Get the real path of a file
---@param path string
function M.realpath(path)
  if path_cache[path] then
    return path_cache[path]
  end
  path = vim.fs.normalize(path, { expand_env = false })
  path_cache[path] = vim.fs.normalize(vim.uv.fs_realpath(path) or path, { expand_env = false, _fast = true })
  return path_cache[path]
end

---@param loc snacks.profiler.Loc
function M.norm(loc)
  local file, line = loc.file, loc.line
  local ret = norm_cache[file] and norm_cache[file][line]
  if not ret then
    ret = M._norm(loc)
    norm_cache[file] = norm_cache[file] or {}
    norm_cache[file][line] = ret
  end
  return ret
end

---@param loc snacks.profiler.Loc
function M._norm(loc)
  if loc.file:sub(1, 4) == "vim/" then
    loc.file = M.user_runtime .. "/lua/" .. loc.file
  elseif loc.file:find("runtime", 1, true) then
    if loc.file:sub(1, #M.vim_runtime) == M.vim_runtime then
      loc.file = M.user_runtime .. "/" .. loc.file:sub(#M.vim_runtime + 2)
    end
  end
  loc.file = M.realpath(loc.file)
  loc.line = loc.line == 0 and 1 or loc.line
  loc.loc = ("%s:%d"):format(loc.file, loc.line)
  if loc.file:find(M.user_config, 1, true) == 1 then
    local relpath = loc.file:sub(#M.user_config + 2)
    local modpath = relpath:match("^lua/(.*)%.lua$")
    loc.modname = modpath and modpath:gsub("/", "."):gsub("%.init$", "") or "vimrc"
    loc.plugin = "user"
  else
    local plugin, modpath = loc.file:match("/([^/]+)/lua/(.*)%.lua$")
    if plugin and modpath then
      plugin = plugin == "runtime" and "nvim" or plugin
      loc.plugin = plugin
      loc.modname = modpath:gsub("/", "."):gsub("%.init$", "")
    end
  end
  return loc
end

---@param entry snacks.profiler.Trace
---@return snacks.profiler.Loc?
function M.loc(entry)
  local ret = fun_cache[entry.fn]
  if ret == nil then
    local info = debug.getinfo(entry.fn, "S")
    if info and info.what ~= "C" then
      ret = { file = info.source:sub(2), line = info.linedefined }
      if entry.fname and ret.file:sub(1, 4) == "vim/" then
        ret.file = M.user_runtime .. "/lua/" .. ret.file
        local ts_loc = M.ts_locs(ret.file)[entry.fname]
        if ts_loc then
          ret.file, ret.line = ts_loc.file, ts_loc.line
        end
      end
      ret = M.norm(ret)
    end
    fun_cache[entry.fn] = ret or false
  end
  return ret or nil
end

---@param file string
function M.ts_locs(file)
  if ts_cache[file] then
    return ts_cache[file]
  end
  ts_query = ts_query
    or vim.treesitter.query.parse(
      "lua",
      [[((function_declaration name: (_) @fun_name) @fun
          (#has-parent? @fun chunk))
        ((return_statement (expression_list (identifier) @ret_name)) @ret
          (#has-parent? @ret chunk))]]
    )
  local source = table.concat(vim.fn.readfile(file), "\n")
  local parser = vim.treesitter.get_string_parser(source, "lua")
  parser:parse()
  local ret, ret_name = {}, nil ---@type table<string, snacks.profiler.Loc>, string?
  local funs = {} ---@type table<string, number>
  for id, node in ts_query:iter_captures(parser:trees()[1]:root(), source) do
    local name = ts_query.captures[id]
    if name == "fun_name" then
      funs[vim.treesitter.get_node_text(node, source)] = node:start() + 1
    elseif name == "ret_name" then
      ret_name = vim.treesitter.get_node_text(node, source)
    end
  end
  for fname, line in pairs(funs) do
    fname = ret_name and fname:gsub("^" .. ret_name .. "%.", "") or fname
    ret[fname] = { file = file, line = line }
  end
  ts_cache[file] = ret
  return ret
end

return M
