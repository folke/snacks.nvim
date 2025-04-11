local M = {}

---@type snacks.picker.finder
function M.spec(opts, ctx)
  local spec = require("lazy.core.config").spec
  local Util = require("lazy.core.util")
  local paths = {} ---@type string[]
  for _, import in ipairs(spec.modules) do
    Util.lsmod(import, function(_, modpath)
      paths[#paths + 1] = modpath
    end)
  end
  local names = {} ---@type string[]
  for _, frag in pairs(spec.meta.fragments.fragments) do
    local name = frag.spec[1] or frag.name
    if not vim.tbl_contains(names, name) then
      names[#names + 1] = name
    end
  end
  local regex = "\\M\\['\"]\\(" .. table.concat(names, "\\|") .. "\\)\\['\"]"
  local re = vim.regex(regex)
  local ret = {} ---@type snacks.picker.finder.Item[]
  for _, path in ipairs(paths) do
    local lines = Snacks.picker.util.lines(path)
    for l, line in ipairs(lines) do
      local from, to = re:match_str(line)
      if from then
        ret[#ret + 1] = {
          file = path,
          line = line,
          text = line,
          pos = { l, from },
          end_pos = { l, to },
        }
      end
    end
  end
  return ret
end

return M
