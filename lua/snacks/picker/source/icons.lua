local M = {}

local NERDFONTS_SETS = {
  cod = "Codicons",
  dev = "Devicons",
  fa = "Font Awesome",
  fae = "Font Awesome Extension",
  iec = "IEC Power Symbols",
  linux = "Font Logos",
  logos = "Font Logos",
  oct = "Octicons",
  ple = "Powerline Extra",
  pom = "Pomicons",
  seti = "Seti-UI",
  weather = "Weather Icons",
  md = "Material Design Icons",
}

---@type table<string, {url: string, v?:number, build: fun(data:table):snacks.picker.Icon[]}>
M.sources = {
  nerd_fonts = {
    url = "https://github.com/ryanoasis/nerd-fonts/raw/refs/heads/master/glyphnames.json",
    v = 4,
    build = function(data)
      ---@cast data table<string, {char:string, code:string}>
      local ret = {} ---@type snacks.picker.Icon[]
      for name, info in pairs(data) do
        if name ~= "METADATA" then
          local font, icon = name:match("^([%w_]+)%-(.*)$")
          if not font then
            error("Invalid icon name: " .. name)
          end
          table.insert(ret, {
            name = icon,
            icon = info.char,
            source = "nerd fonts",
            category = NERDFONTS_SETS[font] or font,
          })
        end
      end
      return ret
    end,
  },
  emoji = {
    url = "https://raw.githubusercontent.com/muan/unicode-emoji-json/refs/heads/main/data-by-emoji.json",
    v = 4,
    build = function(data)
      ---@cast data table<string, {name:string, slug:string, group:string}>
      local ret = {} ---@type snacks.picker.Icon[]
      for icon, info in pairs(data) do
        table.insert(ret, {
          name = info.name,
          icon = icon,
          source = "emoji",
          category = info.group,
        })
      end
      return ret
    end,
  },
}

---@class snacks.picker.Icon: snacks.picker.finder.Item
---@field icon string
---@field name string
---@field source string
---@field category string
---@field desc? string

---@param source_name string
local function load(source_name)
  local source = M.sources[source_name]
  local file = vim.fn.stdpath("cache") .. "/snacks/picker/icons/" .. source_name .. "-v" .. (source.v or 1) .. ".json"
  vim.fn.mkdir(vim.fn.fnamemodify(file, ":h"), "p")
  if vim.fn.filereadable(file) == 1 then
    local fd = assert(io.open(file, "r"))
    local data = fd:read("*a")
    fd:close()
    return vim.json.decode(data) ---@type snacks.picker.Icon[]
  end

  Snacks.notify("Fetching `" .. source_name .. "` icons")
  if vim.fn.executable("curl") == 0 then
    Snacks.notify.error("`curl` is required to fetch icons")
    return {}
  end
  local out = vim.fn.system({ "curl", "-s", "-L", source.url })
  if vim.v.shell_error ~= 0 then
    Snacks.notify.error(out, { title = "Icons Picker" })
    return {}
  end
  local icons = source.build(vim.json.decode(out))
  local fd = assert(io.open(file, "w"))
  fd:write(vim.json.encode(icons))
  fd:close()
  return icons
end

---@param opts snacks.picker.icons.Config
---@type snacks.picker.finder
function M.icons(opts)
  local ret = {} ---@type snacks.picker.Icon[]
  for _, source in ipairs(opts.icon_sources or { "nerd_fonts", "emoji" }) do
    vim.list_extend(ret, load(source))
  end
  for _, icon in ipairs(ret) do
    icon.text = Snacks.picker.util.text(icon, { "source", "category", "name" })
    icon.data = icon.icon
  end
  return ret
end

return M
