---@class snacks.picker.sorters
local M = {}

---@alias snacks.picker.sort.Field { name: string, desc: boolean, len?: boolean }

---@class snacks.picker.sort.Config
---@field fields? (snacks.picker.sort.Field|string)[]

---@param opts? snacks.picker.sort.Config
function M.default(opts)
  local fields = {} ---@type snacks.picker.sort.Field[]
  for _, f in ipairs(opts and opts.fields or { { name = "score", desc = true }, "idx" }) do
    if type(f) == "string" then
      local desc, len = false, nil
      if f:sub(1, 1) == "#" then
        f, len = f:sub(2), true
      end
      if f:sub(-5) == ":desc" then
        f, desc = f:sub(1, -6), true
      elseif f:sub(-4) == ":asc" then
        f = f:sub(1, -5)
      end
      table.insert(fields, { name = f, desc = desc, len = len })
    else
      table.insert(fields, f)
    end
  end

  ---@param a snacks.picker.Item
  ---@param b snacks.picker.Item
  return function(a, b)
    for _, field in ipairs(fields) do
      local av, bv = a[field.name], b[field.name]
      if av ~= nil and bv ~= nil then
        if field.len then
          av, bv = #av, #bv
        end
        if av ~= bv then
          if type(av) == "boolean" then
            av, bv = av and 0 or 1, bv and 0 or 1
          end
          if field.desc then
            return av > bv
          else
            return av < bv
          end
        end
      end
    end
    return false
  end
end

function M.idx()
  ---@param a snacks.picker.Item
  ---@param b snacks.picker.Item
  return function(a, b)
    return a.idx < b.idx
  end
end

return M
