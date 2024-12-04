---@class snacks.lazygit
---@overload fun(opts?: snacks.lazygit.Config): snacks.win
local M = setmetatable({}, {
  __call = function(t, ...)
    return t.open(...)
  end,
})

---@alias snacks.lazygit.Color {fg?:string, bg?:string, bold?:boolean}

---@class snacks.lazygit.Theme: table<number, snacks.lazygit.Color>
---@field activeBorderColor snacks.lazygit.Color
---@field cherryPickedCommitBgColor snacks.lazygit.Color
---@field cherryPickedCommitFgColor snacks.lazygit.Color
---@field defaultFgColor snacks.lazygit.Color
---@field inactiveBorderColor snacks.lazygit.Color
---@field optionsTextColor snacks.lazygit.Color
---@field searchingActiveBorderColor snacks.lazygit.Color
---@field selectedLineBgColor snacks.lazygit.Color
---@field unstagedChangesColor snacks.lazygit.Color

---@class snacks.lazygit.Config: snacks.terminal.Opts
---@field args? string[]
---@field theme? snacks.lazygit.Theme
local defaults = {
  -- automatically configure lazygit to use the current colorscheme
  -- and integrate edit with the current neovim instance
  configure = true,
  -- extra configuration for lazygit that will be merged with the default
  -- snacks does NOT have a full yaml parser, so if you need `"test"` to appear with the quotes
  -- you need to double quote it: `"\"test\""`
  config = {
    os = { editPreset = "nvim-remote" },
    gui = {
      -- set to an empty string "" to disable icons
      nerdFontsVersion = "3",
    },
  },
  theme_path = vim.fs.normalize(vim.fn.stdpath("cache") .. "/lazygit-theme.yml"),
  -- Theme for lazygit
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
    style = "lazygit",
  },
}

Snacks.config.style("lazygit", {})

-- re-create config file on startup
local dirty = true
local config_dir ---@type string?

-- re-create theme file on ColorScheme change
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    dirty = true
  end,
})

---@param opts snacks.lazygit.Config
local function env(opts)
  if not config_dir then
    local out = vim.fn.system({ "lazygit", "-cd" })
    local lines = vim.split(out, "\n", { plain = true })

    if vim.v.shell_error == 0 and #lines > 1 then
      config_dir = vim.split(lines[1], "\n", { plain = true })[1]
      vim.env.LG_CONFIG_FILE = vim.fs.normalize(config_dir .. "/config.yml" .. "," .. opts.theme_path)
    else
      local msg = {
        "Failed to get **lazygit** config directory.",
        "Will not apply **lazygit** config.",
        "",
        "# Error:",
        vim.trim(out),
      }
      Snacks.notify.error(msg, { title = "lazygit" })
    end
  end
end

---@param v snacks.lazygit.Color
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

---@param opts snacks.lazygit.Config
local function update_config(opts)
  ---@type table<string, string[]>
  local theme = {}

  for k, v in pairs(opts.theme) do
    if type(k) == "number" then
      local color = get_color(v)
      -- LazyGit uses color 241 a lot, so also set it to a nice color
      -- pcall, since some terminals don't like this
      pcall(io.write, ("\27]4;%d;%s\7"):format(k, color[1]))
    else
      theme[k] = get_color(v)
    end
  end

  local config = vim.tbl_deep_extend("force", { gui = { theme = theme } }, opts.config or {})

  local function yaml_val(val)
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

-- Opens lazygit, properly configured to use the current colorscheme
-- and integrate with the current neovim instance
---@param opts? snacks.lazygit.Config
function M.open(opts)
  ---@type snacks.lazygit.Config
  opts = Snacks.config.get("lazygit", defaults, opts)

  local cmd = { "lazygit" }
  vim.list_extend(cmd, opts.args or {})

  if opts.configure then
    if dirty then
      update_config(opts)
    end
    env(opts)
  end

  return Snacks.terminal(cmd, opts)
end

-- Opens lazygit with the log view
---@param opts? snacks.lazygit.Config
function M.log(opts)
  opts = opts or {}
  opts.args = opts.args or { "log" }
  return M.open(opts)
end

-- Opens lazygit with the log of the current file
---@param opts? snacks.lazygit.Config
function M.log_file(opts)
  local file = vim.trim(vim.api.nvim_buf_get_name(0))
  opts = opts or {}
  opts.args = { "-f", file }
  opts.cwd = vim.fn.fnamemodify(file, ":h")
  return M.open(opts)
end

---@private
function M.health()
  local ok = vim.fn.executable("lazygit") == 1
  Snacks.health[ok and "ok" or "error"](("{lazygit} %sinstalled"):format(ok and "" or "not "))
end

return M
