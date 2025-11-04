---@class snacks.lsp
local M = {}

---@alias snacks.lsp.handler.cb fun(buf: number, client: vim.lsp.Client):any?

---@class snacks.lsp.Handler
---@field filter vim.lsp.get_clients.Filter
---@field cb snacks.lsp.handler.cb
---@field done table<number, boolean>

local _handlers = {} ---@type snacks.lsp.Handler[]

local did_setup = false

---@param filter vim.lsp.get_clients.Filter
local function _handle(filter)
  ---@param h snacks.lsp.Handler
  local handlers = vim.tbl_filter(function(h)
    ---@diagnostic disable-next-line: no-unknown
    for k, v in pairs(filter) do
      if h.filter[k] ~= nil and h.filter[k] ~= v then
        return false
      end
    end
    return true
  end, _handlers)

  if #handlers == 0 then
    return
  end

  for _, state in ipairs(handlers) do
    local f = vim.deepcopy(state.filter)
    f = vim.tbl_extend("force", f, filter)
    local clients = vim.lsp.get_clients(f)
    for _, client in ipairs(clients) do
      for buf in pairs(client.attached_buffers) do
        local key = ("%d:%d"):format(client.id, buf)
        if not state.done[key] then
          state.done[key] = true
          local ok, err = pcall(state.cb, buf, client)
          if not ok then
            vim.schedule(function()
              Snacks.notify.error(("Error in handler:\n%s\n```lua\n%s\n```"):format(err, vim.inspect(state.filter)))
            end)
          end
        end
      end
    end
  end
end

local function setup()
  if did_setup then
    return
  end
  did_setup = true
  local register_capability = vim.lsp.handlers["client/registerCapability"]
  vim.lsp.handlers["client/registerCapability"] = function(err, res, ctx)
    ---@cast res lsp.RegistrationParams
    local ret = register_capability(err, res, ctx) ---@type any
    vim.schedule(function()
      for _, m in ipairs(res.registrations or {}) do
        _handle({ method = m.method, id = ctx.client_id })
      end
    end)
    return ret
  end
  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("snacks.lsp.on_attach", { clear = true }),
    callback = function(ev)
      vim.schedule(function()
        _handle({ id = ev.data.client_id, buffer = ev.buf })
      end)
    end,
  })
end

---@param filter? vim.lsp.get_clients.Filter
---@param cb snacks.lsp.handler.cb
---@overload fun(cb: snacks.lsp.handler.cb)
function M.on(filter, cb)
  setup()
  filter = filter or {}
  if type(filter) == "function" then
    cb = filter
    filter = {}
  end
  table.insert(_handlers, { filter = filter, cb = cb, done = {} })
  _handle(filter)
end

return M
