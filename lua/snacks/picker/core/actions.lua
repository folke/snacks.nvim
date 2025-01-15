local M = {}

---@alias snacks.picker.Action.fn fun(self: snacks.Picker, item?:snacks.picker.Item):(boolean|string?)
---@alias snacks.picker.Action.spec.one string|snacks.picker.Action|snacks.picker.Action.fn
---@alias snacks.picker.Action.spec snacks.picker.Action.spec.one|snacks.picker.Action.spec.one[]

---@class snacks.picker.Action
---@field action snacks.picker.Action.fn
---@field desc? string

---@param picker snacks.Picker
function M.get(picker)
  local ref = Snacks.util.ref(picker)
  ---@type table<string, snacks.win.Action>
  local ret = {}
  setmetatable(ret, {
    ---@param t table<string, snacks.win.Action>
    ---@param k string
    __index = function(t, k)
      if type(k) ~= "string" then
        return
      end
      local p = ref()
      if not p then
        return
      end
      t[k] = M.resolve(k, p, k) or false
      return rawget(t, k)
    end,
  })
  return ret
end

---@param action snacks.picker.Action.spec
---@param picker snacks.Picker
---@param name? string
---@return snacks.picker.Action?
function M.resolve(action, picker, name)
  if not action then
    assert(name, "Missing action without name")
    local fn, desc = picker.input.win[name], name
    return {
      action = function()
        if not fn then
          return name
        end
        fn(picker.input.win)
      end,
      desc = desc,
    }
  elseif type(action) == "string" then
    return M.resolve(
      (picker.opts.actions or {})[action] or require("snacks.picker.actions")[action],
      picker,
      action:gsub("_ ", " ")
    )
  elseif type(action) == "table" and vim.islist(action) then
    ---@type snacks.picker.Action[]
    local actions = vim.tbl_map(function(a)
      return M.resolve(a, picker)
    end, action)
    return {
      action = function(_, item)
        for _, a in ipairs(actions) do
          a.action(picker, item)
        end
      end,
      desc = table.concat(
        vim.tbl_map(function(a)
          return a.desc
        end, actions),
        ", "
      ),
    }
  end
  action = type(action) == "function" and {
    action = action,
    desc = name or nil,
  } or action
  ---@cast action snacks.picker.Action
  return {
    action = function()
      return action.action(picker, picker:current())
    end,
    desc = action.desc,
  }
end

return M
