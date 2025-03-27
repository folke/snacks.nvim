---@class snacks.health
---@field ok fun(msg: string)
---@field warn fun(msg: string)
---@field error fun(msg: string)
---@field info fun(msg: string)
---@field start fun(msg: string)
local M = setmetatable({}, {
  __index = function(M, k)
    return function(msg)
      return require("vim.health")[k](M.prefix .. msg)
    end
  end,
})

---@class snacks.health.Tool
---@field cmd string|string[]
---@field version? string|false
---@field enabled? boolean

---@alias snacks.health.Tool.spec (string|snacks.health.Tool)[]|snacks.health.Tool|string

M.prefix = ""

M.meta = {
  desc = "Snacks health checks",
  readme = false,
  health = false,
}

function M.check()
  M.prefix = ""
  M.start("Snacks")
  if Snacks.did_setup then
    M.ok("setup called")
    if Snacks.did_setup_after_vim_enter then
      M.warn("setup called *after* `VimEnter`")
    end
  else
    M.error("setup not called")
  end
  if package.loaded.lazy then
    local plugin = require("lazy.core.config").spec.plugins["snacks.nvim"]
    if plugin then
      if plugin.lazy ~= false then
        M.warn("`snacks.nvim` should not be lazy-loaded. Add `lazy=false` to the plugin spec")
      end
      if (plugin.priority or 0) < 1000 then
        M.warn("`snacks.nvim` should have a priority of 1000 or higher. Add `priority=1000` to the plugin spec")
      end
    else
      M.error("`snacks.nvim` not found in lazy")
    end
  end
  for _, plugin in ipairs(Snacks.meta.get()) do
    local opts = Snacks.config[plugin.name] or {} --[[@as {enabled?: boolean}]]
    if plugin.meta.health ~= false and (plugin.meta.needs_setup or plugin.health) then
      M.start(("Snacks.%s"):format(plugin.name))
      -- M.prefix = ("`Snacks.%s` "):format(name)
      if plugin.meta.needs_setup then
        if opts.enabled then
          M.ok("setup {enabled}")
        else
          M.warn("setup {disabled}")
        end
      end
      if plugin.health then
        plugin.health()
      end
    end
  end
end

--- Check if any of the tools are available, with an optional version check
---@param tools snacks.health.Tool.spec
function M.have_tool(tools)
  tools = type(tools) == "string" and { tools } or tools
  tools = tools[1] and tools or { tools }
  ---@cast tools (string|snacks.health.Tool)[]
  tools = vim.tbl_map(function(tool)
    return type(tool) == "string" and { cmd = tool } or tool
  end, tools)
  ---@cast tools snacks.health.Tool[]

  local all = {} ---@type string[]
  local found = false
  local version_ok = false
  for _, tool in ipairs(tools) do
    if tool.enabled ~= false then
      local tool_version = tool.version and vim.version.parse(tool.version)
      local cmds = type(tool.cmd) == "string" and { tool.cmd } or tool.cmd --[[@as string[] ]]
      vim.list_extend(all, cmds)
      for _, cmd in ipairs(cmds) do
        if vim.fn.executable(cmd) == 1 then
          local version = tool.version == false and "" or vim.fn.system(cmd .. " --version") or ""
          version = vim.trim(vim.split(version, "\n")[1])
          if tool_version and tool_version > vim.version.parse(version) then
            M.error("'" .. cmd .. "' `" .. version .. "` is too old, expected `" .. tool.version .. "`")
          elseif tool.version == false then
            M.ok("'" .. cmd .. "'")
            version_ok = true
          else
            M.ok("'" .. cmd .. "' `" .. version .. "`")
            version_ok = true
          end
          found = true
        end
      end
    end
  end
  if found then
    return true, version_ok
  end
  all = vim.tbl_map(function(t)
    return "'" .. tostring(t) .. "'"
  end, all)
  if #all == 1 then
    M.error("Tool not found: " .. all[1])
  else
    M.error("None of the tools found: " .. table.concat(all, ", "))
  end
  return false
end

--- Check if the given languages are available in treesitter
---@param langs string[]|string
function M.has_lang(langs)
  langs = type(langs) == "string" and { langs } or langs --[[@as string[] ]]
  local ret = {} ---@type table<string, boolean>
  local available, missing = {}, {} ---@type string[], string[]
  for _, lang in ipairs(langs) do
    local has_lang = Snacks.util.get_lang(lang) ~= nil
    ret[lang] = has_lang
    lang = ("`%s`"):format(lang)
    if has_lang then
      available[#available + 1] = lang
    else
      missing[#missing + 1] = lang
    end
  end
  table.sort(available)
  table.sort(missing)
  if #available > 0 then
    M.ok("Available Treesitter languages:\n  " .. table.concat(available, ", "))
  end
  if #missing > 0 then
    M.warn("Missing Treesitter languages:\n  " .. table.concat(missing, ", "))
  end
  return ret, #available, #missing
end

return M
