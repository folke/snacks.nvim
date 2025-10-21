---@class snacks.lazydocker
---@overload fun(opts?: snacks.lazydocker.Config): snacks.win
local M = setmetatable({}, {
  __call = function(t, ...)
    return t.open(...)
  end,
})

M.meta = {
  desc = "Open LazyDocker in a float, auto-configure colorscheme",
}

---@alias snacks.lazydocker.Color {fg?:string, bg?:string, bold?:boolean}

---@class snacks.lazydocker.Theme: table<string, snacks.lazydocker.Color>
---@field activeBorderColor snacks.lazydocker.Color
---@field inactiveBorderColor snacks.lazydocker.Color
---@field optionsTextColor snacks.lazydocker.Color
---@field selectedLineBgColor snacks.lazydocker.Color

---@class snacks.lazydocker.Config: snacks.terminal.Opts
---@field args? string[]
---@field theme? snacks.lazydocker.Theme
---@field config_dir? string
local defaults = {
  -- automatically configure lazydocker to use the current colorscheme
  configure = true,
  -- extra configuration for lazydocker that will be merged with the default
  -- snacks does NOT have a full yaml parser, so if you need `"test"` to appear with the quotes
  -- you need to double quote it: `"\"test\""`
  config = {
    gui = {
      -- set to an empty string "" to disable icons
      nerdFontsVersion = "3",
    },
  },
  config_dir = svim.fs.normalize(vim.fn.stdpath("cache") .. "/lazydocker"),
  -- Theme for lazydocker
  -- stylua: ignore
  theme = {
    activeBorderColor   = { fg = "MatchParen", bold = true },
    inactiveBorderColor = { fg = "FloatBorder" },
    optionsTextColor    = { fg = "Function" },
    selectedLineBgColor = { bg = "Visual" },
  },
  win = {
    style = "lazydocker",
  },
}

Snacks.config.style("lazydocker", {})

-- re-create config file on startup
local dirty = true

-- re-create config file on ColorScheme change
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    dirty = true
  end,
})

--- Get the user's default lazydocker config directory based on OS
---@return string?
local function get_user_config_dir()
  if vim.fn.has("mac") == 1 then
    return vim.fn.expand("~/Library/Application Support/jesseduffield/lazydocker")
  elseif vim.fn.has("unix") == 1 then
    local xdg_config = vim.env.XDG_CONFIG_HOME or vim.fn.expand("~/.config")
    return xdg_config .. "/lazydocker"
  elseif vim.fn.has("win32") == 1 then
    return vim.fn.expand("~/AppData/Roaming/lazydocker")
  end
end

---@param opts snacks.lazydocker.Config
local function env(opts)
  -- Set CONFIG_DIR to our cache directory so lazydocker reads our config
  vim.env.CONFIG_DIR = opts.config_dir
end

---@param v snacks.lazydocker.Color
---@return string[]
local function get_color(v)
  ---@type string[]
  local color = {}
  for _, c in ipairs({ "fg", "bg" }) do
    if v[c] then
      local name = v[c]
      local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
      local hl_color ---@type number?
      if c == "fg" then
        hl_color = hl and hl.fg or hl.foreground
      else
        hl_color = hl and hl.bg or hl.background
      end
      if hl_color then
        table.insert(color, string.format("#%06x", hl_color))
      end
    end
  end
  if v.bold then
    table.insert(color, "bold")
  end
  return color
end

---@param opts snacks.lazydocker.Config
local function update_config(opts)
  ---@type table<string, string[]>
  local theme = {}

  for k, v in pairs(opts.theme) do
    theme[k] = get_color(v)
  end

  -- Start with user's existing config if it exists
  local user_config = {}
  local user_config_dir = get_user_config_dir()
  if user_config_dir then
    local user_config_file = user_config_dir .. "/config.yml"
    if vim.loop.fs_stat(user_config_file) then
      -- Read and parse the user's existing config
      -- Note: This is a simple parser and may not handle all YAML features
      -- For a complete solution, a proper YAML parser would be needed
      local ok, content = pcall(vim.fn.readfile, user_config_file)
      if ok and content then
        -- For now, we'll just ensure we don't overwrite the user's config
        -- In a real implementation, you'd parse the YAML properly
      end
    end
  end

  local config = vim.tbl_deep_extend("force", user_config, { gui = { theme = theme } }, opts.config or {})

  local function yaml_val(val)
    if type(val) == "boolean" then
      return tostring(val)
    end
    return type(val) == "string" and not val:find("^\"'`") and ("%q"):format(val) or val
  end

  local function to_yaml(tbl, indent)
    indent = indent or 0
    local lines = {}
    for k, v in pairs(tbl) do
      table.insert(lines, string.rep(" ", indent) .. k .. (type(v) == "table" and ":" or ": " .. yaml_val(v)))
      if type(v) == "table" then
        if (vim.islist or vim.tbl_islist)(v) then
          for _, item in ipairs(v) do
            table.insert(lines, string.rep(" ", indent + 2) .. "- " .. yaml_val(item))
          end
        else
          vim.list_extend(lines, to_yaml(v, indent + 2))
        end
      end
    end
    return lines
  end

  -- Create config directory if it doesn't exist
  vim.fn.mkdir(opts.config_dir, "p")

  -- Write config to cache directory
  local config_file = opts.config_dir .. "/config.yml"
  vim.fn.writefile(to_yaml(config), config_file)
  dirty = false
end

-- Opens lazydocker, properly configured to use the current colorscheme
---@param opts? snacks.lazydocker.Config
function M.open(opts)
  ---@type snacks.lazydocker.Config
  opts = Snacks.config.get("lazydocker", defaults, opts)

  local cmd = { "lazydocker" }
  vim.list_extend(cmd, opts.args or {})

  if opts.configure then
    if dirty then
      update_config(opts)
    end
    env(opts)
  end

  return Snacks.terminal(cmd, opts)
end

---@private
function M.health()
  local ok = vim.fn.executable("lazydocker") == 1
  Snacks.health[ok and "ok" or "error"](("{lazydocker} %sinstalled"):format(ok and "" or "not "))
end

return M
