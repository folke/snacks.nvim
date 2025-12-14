---@diagnostic disable: await-in-sync
local Async = require("snacks.picker.util.async")

local M = {}

local uv = vim.uv or vim.loop
M.USE_QUEUE = true

---@class snacks.picker.proc.Config: snacks.picker.Config
---@field cmd string
---@field sep? string
---@field args? string[]
---@field env? table<string, string>
---@field cwd? string
---@field notify? boolean Notify on failure
---@field transform? snacks.picker.transform
---@field raw? boolean Return raw output without processing

---@param opts snacks.picker.proc.Config
---@type snacks.picker.finder
function M.proc(opts, ctx)
  ---@cast opts snacks.picker.proc.Config
  assert(opts.cmd, "`opts.cmd` is required")

  ---@async
  return function(cb)
    if opts.transform then
      local _cb = cb
      cb = function(item)
        local t = opts.transform(item, ctx)
        item = type(t) == "table" and t or item
        if t ~= false then
          _cb(item)
        end
      end
    end

    if ctx.picker.opts.debug.proc then
      vim.schedule(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        Snacks.debug.cmd(ctx:opts({ group = true }))
      end)
    end

    local sep = opts.sep or "\n"
    local aborted = false
    local stdout = assert(uv.new_pipe())

    local self = Async.running()

    local spawn_opts = {
      args = opts.args,
      stdio = { nil, stdout, nil },
      cwd = opts.cwd and svim.fs.normalize(opts.cwd) or nil,
      env = opts.env,
      hide = true,
    }

    local handle ---@type uv.uv_process_t
    ---@diagnostic disable-next-line: missing-fields
    handle = uv.spawn(opts.cmd, spawn_opts, function(code, _signal)
      if not aborted and code ~= 0 and opts.notify ~= false then
        local full = { opts.cmd or "" }
        vim.list_extend(full, opts.args or {})
        Snacks.notify.error(("Command failed:\n- cmd: `%s`"):format(table.concat(full, " ")))
      end
      handle:close()
      self:resume()
    end)
    if not handle then
      return Snacks.notify.error("Failed to spawn " .. opts.cmd)
    end

    local prev ---@type string?
    local queue = require("snacks.picker.util.queue").new()

    self:on("abort", function()
      stdout:read_stop()
      if not stdout:is_closing() then
        stdout:close()
      end
      aborted = true
      queue:clear()
      cb = function() end
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
      if opts.raw then
        return cb({ text = data })
      end
      local from = 1
      while from <= #data do
        local nl = data:find(sep, from, true)
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

    stdout:read_start(function(err, data)
      assert(not err, err)
      if aborted or not data then
        stdout:close()
        self:resume()
        return
      end
      if M.USE_QUEUE then
        queue:push(data)
        self:resume()
      else
        process(data)
      end
    end)

    while not (stdout:is_closing() and queue:empty()) do
      if queue:empty() then
        self:suspend()
      else
        process(queue:pop())
      end
    end
    -- process the last line
    if prev then
      cb({ text = prev })
    end
  end
end

---@param opts snacks.picker.proc.Config|{[1]: snacks.picker.Config, [2]: snacks.picker.proc.Config}
---@type snacks.picker.finder
function M.json(opts, ctx)
  opts = get_opts(opts) --[[@as snacks.picker.proc.Config]]
  opts.raw = true
  local transform = opts.transform
  opts.transform = nil
  return function(cb)
    local Buffer = require("string.buffer")
    local data = Buffer.new()
    M.proc(opts, ctx)(function(item)
      data:put(item.text)
    end)
    local json = vim.json.decode(data:get())
    assert(svim.islist(json), "Expected JSON array")
    ---@cast json snacks.picker.finder.Item[]
    for _, item in ipairs(json) do
      item = setmetatable({ item = item }, { __index = item })
      item.text = item.text or ""
      local t = transform and transform(item, ctx) or nil
      item = type(t) == "table" and t or item
      if t ~= false then
        cb(item)
      end
    end
  end
end

---@param opts {cmd: string, args?: string[], cwd?: string}
function M.debug(opts)
  vim.schedule(function()
    local lines = { opts.cmd } ---@type string[]
    for _, arg in ipairs(opts.args or {}) do
      arg = arg:find("[$%s]") and vim.fn.shellescape(arg) or arg
      if #arg + #lines[#lines] > 40 then
        lines[#lines] = lines[#lines] .. " \\"
        table.insert(lines, "  " .. arg)
      else
        lines[#lines] = lines[#lines] .. " " .. arg
      end
    end
    local id = opts.cmd
    for _, a in ipairs(opts.args or {}) do
      if a:find("^-") then
        id = id .. " " .. a
      end
    end
    Snacks.notify.info(
      ("- **cwd**: `%s`\n```sh\n%s\n```"):format(
        vim.fn.fnamemodify(svim.fs.normalize(opts.cwd or uv.cwd() or "."), ":~"),
        table.concat(lines, "\n")
      ),
      { id = "snacks.picker.proc." .. id, title = "Snacks Proc" }
    )
  end)
end

return M
