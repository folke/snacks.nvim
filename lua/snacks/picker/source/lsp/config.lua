---@diagnostic disable: await-in-sync
local M = {}

---@class snacks.picker.lsp.config.Item: snacks.picker.finder.Item
---@field name string
---@field config? vim.lsp.ClientConfig
---@field docs? string
---@field buffers table<number, boolean>
---@field attached? boolean
---@field attached_buf? boolean
---@field enabled? boolean
---@field installed? boolean
---@field cmd? string[]
---@field bin? string

---@param opts snacks.picker.lsp.config.Config
---@type snacks.picker.finder
function M.find(opts, ctx)
  local root = vim.api.nvim_get_runtime_file("lua/lspconfig/configs.lua", false)[1]
  if not root then
    Snacks.notify.warn("`nvim-lspconfig` not installed?")
    return {}
  end
  root = root:gsub("%.lua$", "")
  local main_buf = vim.api.nvim_win_get_buf(ctx.picker.main)
  local lspconfig = require("lspconfig.configs")

  ---@param item snacks.picker.lsp.config.Item
  local function resolve(item)
    ---@type boolean, {docs?:{description?:string}, default_config?:vim.lsp.ClientConfig}?
    local ok, mod = pcall(function()
      if lspconfig[item.name] then
        return lspconfig[item.name].config_def
      end
      return loadfile(root .. "/" .. item.name .. ".lua")()
    end)
    if not (ok and mod) then
      return
    end
    item.docs = mod.docs and mod.docs.description or ""
    item.config = item.config or mod.default_config
    item.cmd = item.cmd or lspconfig[item.name] and lspconfig[item.name].cmd
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

  for f in vim.fs.dir(root) do
    local name = f:match("^(.*)%.lua$")
    if name then
      items[name] = items[name]
        or {
          name = name,
          buffers = {},
          enabled = lspconfig[name] and lspconfig[name].manager ~= nil,
        }
      items[name].resolve = resolve
    end
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
    lines[#lines + 1] = "- **cmd**: `" .. table.concat(item.cmd, " ") .. "`"
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

  local clients = vim.lsp.get_clients({ name = item.name })
  if #clients > 0 then
    for _, client in ipairs(clients) do
      lines[#lines + 1] = ""
      lines[#lines + 1] = "## Client [id=" .. client.id .. "]"
      lines[#lines + 1] = ""
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
      lines[#lines + 1] = "- **buffers**: " .. list(vim.tbl_keys(client.attached_buffers))
      local settings = vim.inspect(client.settings)
      lines[#lines + 1] = "- **settings**:"
      lines[#lines + 1] = "```lua\n" .. settings .. "\n```"
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
