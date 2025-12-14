local M = {}

---@alias snacks.picker.Action.fn fun(self: snacks.Picker, item?:snacks.picker.Item, action?:snacks.picker.Action):(boolean|string?)
---@alias snacks.picker.Action.spec.one string|snacks.picker.Action|snacks.picker.Action.fn|{action?:snacks.picker.Action.spec.one}
---@alias snacks.picker.Action.spec snacks.picker.Action.spec.one|snacks.picker.Action.spec.one[]

---@class snacks.picker.Action
---@field action snacks.picker.Action.fn
---@field desc? string
---@field name? string
---@field [string] any additional fields

---@param picker snacks.Picker
function M.get(picker)
  local ref = picker:ref()
  ---@type table<string, snacks.win.Action>
  local ret = {}
  setmetatable(ret, {
    ---@param t table<string, snacks.win.Action>
    ---@param k string
    __index = function(t, k)
      if type(k) ~= "string" then
        return
      end
      t[k] = M.wrap(k, ref, k) or false
      return rawget(t, k)
    end,
  })
  return ret
end

---@param action snacks.picker.Action.spec
---@param ref snacks.Picker.ref
---@param name? string
function M.wrap(action, ref, name)
  local picker = ref()
  if not picker then
    return
  end
  action = M.resolve(action, picker, name)
  action.name = name
  ---@type snacks.win.Action
  return {
    name = name,
    action = function()
      local p = ref()
      if not p then
        return
      end
      return action.action(p, p:current(), action)
    end,
    desc = action.desc,
  }
end

---@param action snacks.picker.Action.spec
---@param picker snacks.Picker
---@param name? string
---@param stack? string[]
---@return snacks.picker.Action
function M.resolve(action, picker, name, stack)
  stack = stack or {}
  if not action then
    assert(name, "Missing action without name")
    local fn, desc = picker.input.win[name], name
    return {
      action = function(p)
        if not fn then
          return name
        end
        fn(p.input.win)
      end,
      desc = desc,
    }
  elseif type(action) == "string" then
    if vim.tbl_contains(stack, action) then
      if action == "confirm" or name == "confirm" then
        action = "jump"
      else
        Snacks.notify.error("Circular action reference for `" .. action .. "`:\n- " .. table.concat(stack, "\n- "))
        return {}
      end
    end
    stack[#stack + 1] = action
    return M.resolve(Snacks.picker.config.action(picker, action), picker, action, stack)
  elseif type(action) == "table" and svim.islist(action) then
    local actions = vim.tbl_map(function(a)
      return M.resolve(a, picker, nil, stack)
    end, action)
    ---@type snacks.picker.Action
    return {
      action = function(p, i)
        for _, a in ipairs(actions) do
          a.action(p, i, a)
        end
      end,
      desc = table.concat(
        vim.tbl_map(function(a)
          return a.desc or a.name or "unknown"
        end, actions),
        ", "
      ),
    }
  elseif type(action) == "table" then
    if type(action.action) ~= "function" then
      action = vim.deepcopy(action)
      action.action = M.resolve(action.action, picker, nil, stack).action
    end
    ---@cast action snacks.picker.Action
    action.desc = action.desc or name or nil
    return action
  end
  assert(type(action) == "function", "Invalid action")
  return {
    action = action,
    desc = name or nil,
  }
end

return M
