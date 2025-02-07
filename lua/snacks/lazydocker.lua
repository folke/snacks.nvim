---@class snacks.lazydocker
---@overload fun(opts?: snacks.lazydocker.Config): snacks.win
local M = setmetatable({}, {
  __call = function(t, ...)
    return t.open(...)
  end,
})

M.meta = {
  desc = "Open LazyDocker in a float, auto-configure colorscheme and integration with Neovim",
}

---@alias snacks.lazydocker.Color {fg?:string, bg?:string, bold?:boolean}

---@class snacks.lazydocker.Theme: table<number, snacks.lazydocker.Color>
---@field activeBorderColor snacks.lazydocker.Color
---@field cherryPickedCommitBgColor snacks.lazydocker.Color
---@field cherryPickedCommitFgColor snacks.lazydocker.Color
---@field defaultFgColor snacks.lazydocker.Color
---@field inactiveBorderColor snacks.lazydocker.Color
---@field optionsTextColor snacks.lazydocker.Color
---@field searchingActiveBorderColor snacks.lazydocker.Color
---@field selectedLineBgColor snacks.lazydocker.Color
---@field unstagedChangesColor snacks.lazydocker.Color

---@class snacks.lazydocker.Config: snacks.terminal.Opts
---@field args? string[]
---@field theme? snacks.lazydocker.Theme
local defaults = {
  -- automatically configure lazydocker to use the current colorscheme
  -- and integrate edit with the current neovim instance
  configure = true,
  -- extra configuration for lazydocker that will be merged with the default
  -- snacks does NOT have a full yaml parser, so if you need `"test"` to appear with the quotes
  -- you need to double quote it: `"\"test\""`
  config = {
    os = { editPreset = "nvim-remote" },
    gui = {
      -- set to an empty string "" to disable icons
      nerdFontsVersion = "3",
    },
  },
  theme_path = vim.fs.normalize(vim.fn.stdpath("cache") .. "/lazydocker-theme.yml"),
  -- Theme for lazydocker
  -- stylua: ignore
  theme = {
    [241]                      = { fg = "Special" },
    activeBorderColor          = { fg = "MatchParen", bold = true },
    cherryPickedCommitBgColor  = { fg = "Identifier" },
    cherryPickedCommitFgColor  = { fg = "Function" },
    defaultFgColor             = { fg = "Normal" },
    inactiveBorderColor        = { fg = "FloatBorder" },
    optionsTextColor           = { fg = "Function" },
    searchingActiveBorderColor = { fg = "MatchParen", bold = true },
    selectedLineBgColor        = { bg = "Visual" }, -- set to `default` to have no background colour
    unstagedChangesColor       = { fg = "DiagnosticError" },
  },
  win = {
    style = "lazydocker",
  },
}

Snacks.config.style("lazydocker", {})

-- re-create config file on startup
local dirty = true
local config_dir ---@type string?

-- re-create theme file on ColorScheme change
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    dirty = true
  end,
})

---@param opts snacks.lazydocker.Config
local function env(opts)
  if not config_dir then
    local out = vim.fn.system({ "lazydocker", "-c" })
    local lines = vim.split(out, "\n", { plain = true })

    if vim.v.shell_error == 0 and #lines > 1 then
      config_dir = vim.split(lines[1], "\n", { plain = true })[1]

      ---@type string[]
      local config_files = vim.tbl_filter(function(v)
        return v:match("%S")
      end, vim.split(vim.env.LG_CONFIG_FILE or "", ",", { plain = true }))

      -- add the default config file if it's not already there
      if #config_files == 0 then
        config_files[1] = vim.fs.normalize(config_dir .. "/config.yml")
      end

      -- add the theme file if it's not already there
      if not vim.tbl_contains(config_files, opts.theme_path) then
        table.insert(config_files, opts.theme_path)
      end

      vim.env.LG_CONFIG_FILE = table.concat(config_files, ",")
    else
      local msg = {
        "Failed to get **lazydocker** config directory.",
        "Will not apply **lazydocker** config.",
        "",
        "# Error:",
        vim.trim(out),
      }
      Snacks.notify.error(msg, { title = "lazydocker" })
    end
  end
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
    if type(k) == "number" then
      local color = get_color(v)
      -- Lazydocker uses color 241 a lot, so also set it to a nice color
      -- pcall, since some terminals don't like this
      pcall(io.write, ("\27]4;%d;%s\7"):format(k, color[1]))
    else
      theme[k] = get_color(v)
    end
  end

  local config = vim.tbl_deep_extend("force", { gui = { theme = theme } }, opts.config or {})

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
  vim.fn.writefile(to_yaml(config), opts.theme_path)
  dirty = false
end

-- Opens lazydocker, properly configured to use the current colorscheme
-- and integrate with the current neovim instance
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
