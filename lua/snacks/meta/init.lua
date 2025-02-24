---@class snacks.meta
local M = {}

M.meta = {
  desc = "Meta functions for Snacks",
  readme = false,
}

---@class snacks.meta.Meta
---@field desc string
---@field needs_setup? boolean
---@field hide? boolean
---@field readme? boolean
---@field docs? boolean
---@field health? boolean
---@field types? boolean
---@field config? boolean
---@field merge? { [string|number]: string }

---@class snacks.meta.Plugin
---@field name string
---@field file string
---@field meta snacks.meta.Meta
---@field health? fun()

M.root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")

function M.file(name)
  return svim.fs.normalize(("%s/%s"):format(M.root, name))
end

--- Get the metadata for all snacks plugins
---@return snacks.meta.Plugin[]
function M.get()
  local ret = {} ---@type snacks.meta.Plugin[]
  for file, t in vim.fs.dir(M.root, { depth = 1 }) do
    if file:sub(1, 1) ~= "." then
      local name = vim.fn.fnamemodify(file, ":t:r")
      file = t == "directory" and ("%s/init.lua"):format(file) or file
      file = M.root .. "/" .. file
      local mod = name == "init" and setmetatable({ meta = { desc = "Snacks", hide = true } }, { __index = Snacks })
        or Snacks[name] --[[@as snacks.meta.Plugin]]
      assert(type(mod) == "table", ("`Snacks.%s` not found"):format(name))
      assert(type(mod.meta) == "table", ("`Snacks.%s.meta` not found"):format(name))
      assert(type(mod.meta.desc) == "string", ("`Snacks.%s.meta.desc` not found"):format(name))

      for _, prop in ipairs({ "readme", "docs", "health", "types" }) do
        if mod.meta[prop] == nil then
          mod.meta[prop] = not mod.meta.hide
        end
      end

      ret[#ret + 1] = setmetatable({
        name = name,
        file = file,
      }, {
        __index = mod,
        __tostring = function(self)
          return "snacks." .. self.name
        end,
      })
    end
  end
  table.sort(ret, function(a, b)
    return a.name < b.name
  end)
  return ret
end

return M
