---@diagnostic disable: await-in-sync
local M = {}

local has_11 = vim.fn.has("nvim-0.11") == 1

---@class snacks.picker.lsp.config.Item: snacks.picker.finder.Item
---@field name string
---@field config? vim.lsp.ClientConfig
---@field docs? string
---@field buffers table<number, boolean>
---@field attached? boolean
---@field attached_buf? boolean
---@field enabled? boolean
---@field installed? boolean
---@field deprecated? boolean
---@field cmd? string[]
---@field bin? string

---@class snacks.picker.lsp.config.Config
---@field config vim.lsp.Config
---@field enabled? boolean
---@field docs? string
---@field deprecated? boolean

---@param name string
local function is_enabled(name)
  if has_11 then
    return vim.lsp.is_enabled(name)
  end
  local lspconfig = require("lspconfig.configs")
  return lspconfig[name] and lspconfig[name].manager ~= nil
end

---@param name string
local function get_config(name)
  local modpath = vim.api.nvim_get_runtime_file("lsp/" .. name .. ".lua", false)[1]
  local ret = { config = {} } ---@type snacks.picker.lsp.config.Config
  local deprecate = vim.deprecate
  vim.deprecate = function()
    ret.deprecated = true
  end
  local ok, config = pcall(function()
    return has_11 and vim.lsp.config[name] or loadfile(modpath)() or {}
  end)
  vim.deprecate = deprecate
  ret.config = ok and config or {}
  ret.enabled = is_enabled(name)
  local lines = modpath and Snacks.picker.util.lines(modpath) or {}
  local header = {} ---@type string[]
  for _, line in ipairs(lines) do
    if line:match("^%s*%-%-") then
      if not line:match("@brief") then
        header[#header + 1] = line:gsub("^%s*%-%-+%s?", "")
      end
    elseif not line:match("^%s*$") then
      break
    end
  end
  ret.docs = vim.trim(table.concat(header, "\n"))
  return ret
end

---@param opts snacks.picker.lsp.config.Config
---@type snacks.picker.finder
function M.find(opts, ctx)
  local all = vim.api.nvim_get_runtime_file("lsp/*.lua", true)
  local available = {} ---@type table<string, string>
  for _, f in ipairs(all) do
    local name = f:match("([^/\\]+)%.lua$")
    if name then
      available[name] = name
    end
  end

  for name in pairs(has_11 and vim.lsp.config._configs or {}) do
    available[name] = name
  end

  if vim.tbl_count(available) == 0 then
    Snacks.notify.warn("No LSP configurations found?")
    return {}
  end
  local main_buf = vim.api.nvim_win_get_buf(ctx.picker.main)

  ---@param item snacks.picker.lsp.config.Item
  local function resolve(item)
    local mod = get_config(item.name)
    item.docs = item.docs or mod.docs
    item.config = item.config or mod.config
    item.cmd = item.cmd or mod.config.cmd
    item.enabled = item.enabled or mod.enabled
    item.deprecated = mod.deprecated
  end

  local items = {} ---@type table<string, snacks.picker.lsp.config.Item>
  for _, client in ipairs(vim.lsp.get_clients()) do
    items[client.name] = items[client.name]
      or {
        name = client.name,
        buffers = {},
        config = client.config,
        attached = true,
        enabled = true,
        cmd = client.config.cmd,
      }
    for buf in pairs(client.attached_buffers) do
      items[client.name].buffers[buf] = true
    end
    items[client.name].attached_buf = items[client.name].buffers[main_buf]
  end

  for name in pairs(available) do
    items[name] = items[name] or {
      name = name,
      buffers = {},
    }
    items[name].resolve = resolve
  end

  ---@param cb async fun(item: snacks.picker.finder.Item)
  return function(cb)
    local bins = Snacks.picker.util.get_bins()
    for name, item in pairs(items) do
      Snacks.picker.util.resolve(item)
      local config = item.config or {}
      local cmd = item.cmd or type(config.cmd) == "table" and config.cmd or nil
      local bin ---@type string?
      local installed = false
      if type(cmd) == "table" and #cmd > 0 then
        ---@type string[]
        cmd = vim.deepcopy(cmd)
        cmd[1] = svim.fs.normalize(cmd[1])
        if cmd[1]:find("/") then
          installed = vim.fn.filereadable(cmd[1]) == 1
          bin = cmd[1]
        else
          bin = bins[cmd[1]] or cmd[1]
          installed = bins[cmd[1]] ~= nil
        end
        cmd[1] = vim.fs.basename(cmd[1])
      end
      local want = (not opts.installed or installed) and (not opts.configured or item.enabled)
      if opts.attached == true and not item.attached then
        want = false
      elseif type(opts.attached) == "number" then
        local buf = opts.attached == 0 and main_buf or opts.attached
        if not item.buffers[buf] then
          want = false
        end
      end
      want = want and not item.deprecated
      if want then
        cb({
          name = name,
          cmd = cmd,
          bin = bin,
          installed = installed,
          enabled = item.enabled or false,
          buffers = item.buffers,
          attached = item.attached or false,
          attached_buf = item.attached_buf or false,
          text = name .. " " .. table.concat(config.filetypes or {}, " "),
          docs = item.docs,
          config = config,
        })
      end
    end
  end
end

---@param item snacks.picker.Item
---@param picker snacks.Picker
function M.format(item, picker)
  local a = Snacks.picker.util.align
  local ret = {} ---@type snacks.picker.Highlight[]
  local config = item.config ---@type vim.lsp.ClientConfig
  local icons = picker.opts.icons.lsp
  if item.attached_buf then
    ret[#ret + 1] = { a(icons.attached, 2), "SnacksPickerLspAttachedBuf" }
  elseif item.attached then
    ret[#ret + 1] = { a(icons.attached, 2), "SnacksPickerLspAttached" }
  elseif item.enabled then
    ret[#ret + 1] = { a(icons.enabled, 2), "SnacksPickerLspEnabled" }
  elseif item.installed then
    ret[#ret + 1] = { a(icons.disabled, 2), "SnacksPickerLspDisabled" }
  else
    ret[#ret + 1] = { a(icons.unavailable, 2), "SnacksPickerLspUnavailable" }
  end
  ret[#ret + 1] = { a(item.name, 20) }
  for _, ft in ipairs(config.filetypes or {}) do
    ret[#ret + 1] = { " " }
    local icon, hl = Snacks.util.icon(ft, "filetype")
    ret[#ret + 1] = { a(icon, 2), hl }
    ret[#ret + 1] = { ft, "SnacksPickerDimmed" }
  end

  return ret
end

---@param ctx snacks.picker.preview.ctx
function M.preview(ctx)
  local config = ctx.item.config ---@type vim.lsp.ClientConfig
  local item = ctx.item --[[@as snacks.picker.lsp.config.Item]]
  local lines = {} ---@type string[]
  lines[#lines + 1] = "# `" .. item.name .. "`"
  lines[#lines + 1] = ""

  ---@param path string
  local function norm(path)
    return vim.fn.fnamemodify(path, ":p:~"):gsub("[\\/]$", "")
  end

  local function list(values)
    return table.concat(
      vim.tbl_map(function(v)
        return "`" .. v .. "`"
      end, values),
      ", "
    )
  end

  if item.cmd then
    local cmd = type(item.cmd) == "function" and "<function>" or table.concat(item.cmd, " ")
    lines[#lines + 1] = "- **cmd**: `" .. cmd .. "`"
  end

  if item.installed then
    lines[#lines + 1] = "- **installed**: `" .. norm(item.bin) .. "`"
    lines[#lines + 1] = "- **enabled**: " .. (item.enabled and "yes" or "no")
  else
    lines[#lines + 1] = "- **installed**: " .. (item.bin and "`" .. item.bin .. "` " or "") .. "not installed"
  end
  local ft = config.filetypes or {}
  if #ft > 0 then
    lines[#lines + 1] = "- **filetypes**: " .. list(ft)
  end

  -- root markers
  local markers = config.root_markers or {}
  if #markers > 0 then
    lines[#lines + 1] = "- **root markers**: " .. list(markers)
  end

  local clients = vim.lsp.get_clients({ name = item.name })
  if #clients > 0 then
    for _, client in ipairs(clients) do
      lines[#lines + 1] = ""
      lines[#lines + 1] = "## Client [id=" .. client.id .. "]"
      lines[#lines + 1] = ""

      -- server info
      for k, v in pairs(client.server_info or {}) do
        lines[#lines + 1] = ("- **%s**: `%s`"):format(k, v)
      end

      -- workspaces
      local roots = {} ---@type string[]
      for _, ws in ipairs(client.workspace_folders or {}) do
        roots[#roots + 1] = vim.uri_to_fname(ws.uri)
      end
      roots = #roots == 0 and { client.root_dir } or roots
      if #roots > 0 then
        if #roots > 1 then
          lines[#lines + 1] = "- **workspace**:"
          for _, root in ipairs(roots) do
            lines[#lines + 1] = "    - `" .. norm(root) .. "`"
          end
        else
          lines[#lines + 1] = "- **workspace**: `" .. norm(roots[1]) .. "`"
        end
      end

      -- buffers
      lines[#lines + 1] = "- **buffers**: " .. list(vim.tbl_keys(client.attached_buffers))

      -- settings
      local settings = vim.inspect(client.settings)
      lines[#lines + 1] = "- **settings**:"
      lines[#lines + 1] = "```lua\n" .. settings .. "\n```"

      -- init options
      if client.config.init_options then
        local init_options = vim.inspect(client.config.init_options)
        lines[#lines + 1] = "- **init options**:"
        lines[#lines + 1] = "```lua\n" .. init_options .. "\n```"
      end
    end
  end

  if item.docs then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "## Docs"
    lines[#lines + 1] = ""
    lines[#lines + 1] = item.docs
  end
  ctx.preview:set_lines(lines)
  ctx.preview:highlight({ ft = "markdown" })
end

return M
