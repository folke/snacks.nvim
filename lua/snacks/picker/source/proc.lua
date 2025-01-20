local Async = require("snacks.picker.util.async")

local M = {}

local uv = vim.uv or vim.loop
M.USE_QUEUE = true

---@alias snacks.picker.transform fun(item:snacks.picker.finder.Item):(false|snacks.picker.finder.Item?)

---@class snacks.picker.proc.Config: snacks.picker.Config
---@field cmd string
---@field args? string[]
---@field env? table<string, string>
---@field cwd? string
---@field notify? boolean Notify on failure
---@field transform? snacks.picker.transform

---@param opts snacks.picker.proc.Config
---@return fun(cb:async fun(item:snacks.picker.finder.Item))
function M.proc(opts)
  assert(opts.cmd, "`opts.cmd` is required")
  ---@async
  return function(cb)
    if opts.transform then
      local _cb = cb
      cb = function(item)
        local t = opts.transform(item)
        item = type(t) == "table" and t or item
        if t ~= false then
          _cb(item)
        end
      end
    end
    local aborted = false
    local stdout = assert(uv.new_pipe())
    opts = vim.tbl_deep_extend("force", {}, opts or {}, {
      stdio = { nil, stdout, nil },
      cwd = opts.cwd and vim.fs.normalize(opts.cwd) or nil,
    }) --[[@as snacks.picker.proc.Config]]
    local self = Async.running()

    local handle ---@type uv.uv_process_t
    handle = uv.spawn(opts.cmd, opts, function(code, _signal)
      if not aborted and code ~= 0 and opts.notify ~= false then
        local full = { opts.cmd or "" }
        vim.list_extend(full, opts.args or {})
        return Snacks.notify.error(("Command failed:\n- cmd: `%s`"):format(table.concat(full, " ")))
      end
      stdout:close()
      handle:close()
      self:resume()
    end)
    if not handle then
      return Snacks.notify.error("Failed to spawn " .. opts.cmd)
    end

    local prev ---@type string?

    self:on("abort", function()
      aborted = true
      if not handle:is_closing() then
        handle:kill("sigterm")
        vim.defer_fn(function()
          if not handle:is_closing() then
            handle:kill("sigkill")
          end
        end, 200)
      end
    end)

    ---@param data? string
    local function process(data)
      if aborted then
        return
      end
      if not data then
        return prev and cb({ text = prev })
      end
      local from = 1
      while from <= #data do
        local nl = data:find("\n", from, true)
        if nl then
          local cr = data:byte(nl - 1, nl - 1) == 13 -- \r
          local line = data:sub(from, nl - (cr and 2 or 1))
          if prev then
            line, prev = prev .. line, nil
          end
          cb({ text = line })
          from = nl + 1
        elseif prev then
          prev = prev .. data:sub(from)
          break
        else
          prev = data:sub(from)
          break
        end
      end
    end

    local queue = require("snacks.picker.util.queue").new()

    stdout:read_start(function(err, data)
      assert(not err, err)
      if M.USE_QUEUE then
        queue:push(data)
        self:resume()
      else
        process(data)
      end
    end)

    while not (handle:is_closing() and queue:empty()) do
      if queue:empty() then
        self:suspend()
      else
        process(queue:pop())
      end
    end
  end
end

return M
