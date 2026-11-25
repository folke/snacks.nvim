local Async = require("snacks.picker.util.async")

---@module 'uv'

local M = {}

---@diagnostic disable-next-line: deprecated
local lsp_get_clients = vim.lsp.get_clients or vim.lsp.get_active_clients

---@alias lsp.Symbol lsp.SymbolInformation|lsp.DocumentSymbol
---@alias lsp.Loc lsp.LocationLink|lsp.Location

---@class snacks.picker.lsp.Loc: lsp.Location
---@field encoding string
---@field resolved? boolean

local kinds = nil ---@type table<lsp.SymbolKind, string>

--- Gets the original symbol kind name from its number.
--- Some plugins override the symbol kind names, so this function is needed to get the original name.
---@param kind lsp.SymbolKind
---@return string
function M.symbol_kind(kind)
  if not kinds then
    kinds = {}
    for k, v in pairs(vim.lsp.protocol.SymbolKind) do
      if type(v) == "number" then
        kinds[v] = k
      end
    end
  end
  return kinds[kind] or "Unknown"
end

--- Neovim 0.11 uses a lua class for clients, while older versions use a table.
--- Wraps older style clients to be compatible with the new style.
---@param client vim.lsp.Client
---@return vim.lsp.Client
local function wrap(client)
  local meta = getmetatable(client)
  if meta and meta.request then
    return client
  end
  ---@diagnostic disable-next-line: undefined-field
  if client.wrapped then
    return client
  end
  local methods = { "request", "supports_method", "cancel_request", "notify" }
  -- old style
  return setmetatable({ wrapped = true }, {
    __index = function(_, k)
      if k == "supports_method" then
        -- supports_method doesn't support the bufnr argument
        return function(_, method)
          return client[k](method)
        end
      end
      if vim.tbl_contains(methods, k) then
        return function(_, ...)
          return client[k](...)
        end
      end
      return client[k]
    end,
  })
end

---@param item snacks.picker.finder.Item
---@param result lsp.Loc
---@param client vim.lsp.Client
function M.add_loc(item, result, client)
  ---@type snacks.picker.lsp.Loc
  local loc = {
    uri = result.uri or result.targetUri,
    range = result.range or result.targetSelectionRange,
    encoding = client.offset_encoding,
  }
  item.loc = loc
  item.pos = { loc.range.start.line + 1, loc.range.start.character }
  item.end_pos = { loc.range["end"].line + 1, loc.range["end"].character }
  item.file = vim.uri_to_fname(loc.uri)
  return item
end

---@param buf number
---@param method string
---@return vim.lsp.Client[]
function M.get_clients(buf, method)
  ---@param client vim.lsp.Client
  local clients = vim.tbl_map(function(client)
    return wrap(client)
  end, lsp_get_clients({ bufnr = buf }))
  ---@param client vim.lsp.Client
  clients = vim.tbl_filter(function(client)
    return client:supports_method(method, buf)
  end, clients)
  if #clients == 0 and method == "workspace/symbol" then
    ---@param client vim.lsp.Client
    local all_clients = vim.tbl_map(function(client)
      return wrap(client)
    end, lsp_get_clients({ method = method }))
    local cwd = svim.fs.normalize((vim.uv or vim.loop).cwd() or ".")
    ---@param client vim.lsp.Client
    local matching = vim.tbl_filter(function(client)
      local root = client.root_dir or (client.config and client.config.root_dir)
      root = root and svim.fs.normalize(root)
      return root ~= nil and (root == cwd or vim.startswith(cwd, root .. "/"))
    end, all_clients)
    return #matching > 0 and matching or all_clients
  end
  return clients
end

---@class snacks.picker.lsp.Requester
---@field async snacks.picker.Async
---@field requests table<string, {client_id:number, request_id:number, done:boolean}>
---@field pending integer
---@field autocmd_id? number
local R = {}
R.__index = R
R._id = 0

function R.new()
  local self = setmetatable({}, R)
  self.async = Async.running()
  self.requests = {}
  self.pending = 0
  R._id = R._id + 1

  self.async
    :on(
      "abort",
      vim.schedule_wrap(function()
        self:cancel()
      end)
    )
    :on(
      "done",
      vim.schedule_wrap(function()
        pcall(vim.api.nvim_del_autocmd, self.autocmd_id)
      end)
    )
  return self
end

---@param clients vim.lsp.Client[]
---@param ctx lsp.HandlerContext
function R:debug(clients, ctx)
  Snacks.debug.inspect({
    error = "LSP request callback yielded after done.",
    method = ctx.method,
    requests = vim.deepcopy(self.requests),
    pending = self.pending,
    client_id = ctx.client_id,
    ---@param c vim.lsp.Client
    clients = vim.tbl_map(function(c)
      return { id = c.id, name = c.name }
    end, clients),
  })
end

---@param client_id number
---@param request_id number
---@param completed? boolean
function R:track(client_id, request_id, completed)
  local key = ("%d:%d"):format(client_id, request_id)
  if completed and self.requests[key] and not self.requests[key].done then
    self.requests[key].done = true
    self.pending = self.pending - 1
    self.async:resume()
    return
  elseif not completed then
    self.requests[key] = { client_id = client_id, request_id = request_id, done = false }
    self.pending = self.pending + 1
  end
end

function R:cancel()
  while #self.requests > 0 do
    local req = table.remove(self.requests)
    local client = vim.lsp.get_client_by_id(req.client_id)
    if client then
      client:cancel_request(req.request_id)
    end
  end
end

function R:track_cancel()
  if self.autocmd_id then
    return
  end
  self.autocmd_id = vim.api.nvim_create_autocmd("LspRequest", {
    group = vim.api.nvim_create_augroup("snacks.picker.lsp.cancel." .. R._id, { clear = true }),
    callback = function(ev)
      if ev.data.request.type == "cancel" then
        self:track(ev.data.client_id, ev.data.request_id, true)
      end
    end,
  })
end

---@param buf number|vim.lsp.Client
---@param method string
---@param params fun(client:vim.lsp.Client):table
---@param cb fun(client:vim.lsp.Client, result:table, params:table)
---@async
function R:request(buf, method, params, cb)
  self.pending = self.pending + 1
  vim.schedule(function()
    self:track_cancel() -- setup autocmd here, since this must be called in the main loop

    ---@diagnostic disable-next-line: param-type-mismatch
    local clients = type(buf) == "number" and M.get_clients(buf, method) or { wrap(buf) }

    self.pending = self.pending + #clients
    for _, client in ipairs(clients) do
      local done = false
      local status, request_id ---@type boolean, number?
      status, request_id = client:request(method, params(client), function(err, result, ctx)
        done = true
        if not err and result and not self.async:aborted() then
          if not self.async:running() or self.pending <= 0 then
            self:debug(clients, ctx)
          end
          cb(client, result, ctx.params)
        end
        if request_id then
          self:track(client.id, request_id, true)
        end
      end)
      -- skip tracking if the request failed
      -- or is already done (in-process syncronous response)
      if status and request_id and not done then
        self:track(client.id, request_id)
      end
    end
    self.pending = self.pending - 1 - #clients
    self.async:resume()
  end)
  return self
end

---@param flush? async fun()
---@async
function R:wait(flush)
  while self.pending > 0 do
    self.async:suspend()
    if flush then
      flush()
    end
  end
  if flush then
    flush()
  end
end

---@param cb async fun(item: snacks.picker.finder.Item)
---@return fun(item: snacks.picker.finder.Item), async fun()
local function wrap_cb(cb)
  local queue = {} ---@type snacks.picker.finder.Item[]
  ---@param item snacks.picker.finder.Item
  local function add(item)
    queue[#queue + 1] = item
  end
  ---@async
  local function flush()
    while #queue > 0 do
      local batch = queue
      queue = {}
      for _, item in ipairs(batch) do
        cb(item)
      end
    end
  end
  return add, flush
end

---@return boolean
local function has_uninitialized_clients()
  for _, client in ipairs(lsp_get_clients({ _uninitialized = true })) do
    if not client.initialized then
      return true
    end
  end
  return false
end

---@param buf number
---@param method string
---@async
local function wait_for_clients(buf, method)
  local async = Async.running()
  local function ready()
    return #M.get_clients(buf, method) > 0 or not has_uninitialized_clients()
  end
  if async:schedule(ready) then
    return
  end
  for _ = 1, 50 do
    if async:aborted() or async:defer(100, ready) then
      break
    end
  end
end

---@param buf number
---@param method string
---@param params fun(client:vim.lsp.Client):table
---@param cb fun(client:vim.lsp.Client, result:table, params:table)
---@param flush? async fun()
---@async
function M.request(buf, method, params, cb, flush)
  wait_for_clients(buf, method)
  R.new():request(buf, method, params, cb):wait(flush)
end

-- Support for older versions of neovim
---@param locs vim.quickfix.entry[]
function M.fix_locs(locs)
  for _, loc in ipairs(locs) do
    local range = loc.user_data and loc.user_data.range or nil ---@type lsp.Range?
    if range then
      if not loc.end_lnum then
        if range.start.line == range["end"].line then
          loc.end_lnum = loc.lnum
          loc.end_col = loc.col + range["end"].character - range.start.character
        end
      end
    end
  end
end

function M.bufmap()
  local bufmap = {} ---@type table<string,number>
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].buflisted and vim.bo[b].buftype == "" and vim.api.nvim_buf_is_loaded(b) then
      local name = vim.api.nvim_buf_get_name(b)
      if name ~= "" then
        bufmap[name] = b
      end
    end
  end
  return bufmap
end

---@param method string
---@param opts snacks.picker.lsp.Config|{context?:lsp.ReferenceContext}
---@param filter snacks.picker.Filter
function M.get_locations(method, opts, filter)
  local win = filter.current_win
  local buf = filter.current_buf
  local fname = vim.api.nvim_buf_get_name(buf)
  fname = svim.fs.normalize(fname)
  local cursor = vim.api.nvim_win_get_cursor(win)
  local bufmap = M.bufmap()

  ---@async
  ---@param cb async fun(item: snacks.picker.finder.Item)
  return function(cb)
    local add, flush = wrap_cb(cb)
    local done = {} ---@type table<string, boolean>
    M.request(buf, method, function(client)
      local params = vim.lsp.util.make_position_params(win, client.offset_encoding)
      ---@diagnostic disable-next-line: inject-field
      params.context = opts.context
      return params
    end, function(client, result)
      result = result or {}
      -- Result can be a single item or a list of items
      result = vim.tbl_isempty(result) and {} or svim.islist(result) and result or { result }

      local items = vim.lsp.util.locations_to_items(result or {}, client.offset_encoding)
      M.fix_locs(items)

      if not opts.include_current then
        ---@param item vim.quickfix.entry
        items = vim.tbl_filter(function(item)
          if svim.fs.normalize(item.filename) ~= fname then
            return true
          end
          if not item.lnum then
            return true
          end
          if item.lnum == cursor[1] then
            return false
          end
          if not item.end_lnum then
            return true
          end
          return not (item.lnum <= cursor[1] and item.end_lnum >= cursor[1])
        end, items)
      end

      for _, loc in ipairs(items) do
        ---@type snacks.picker.finder.Item
        local item = {
          text = loc.filename .. " " .. loc.text,
          buf = bufmap[loc.filename],
          file = loc.filename,
          pos = { loc.lnum, loc.col - 1 },
          end_pos = loc.end_lnum and loc.end_col and { loc.end_lnum, loc.end_col - 1 } or nil,
          line = loc.text,
        }
        local loc_key = loc.filename .. ":" .. loc.lnum
        if filter:match(item) and not (done[loc_key] and opts.unique_lines) then
          add(item)
          done[loc_key] = true
        end
      end
    end, flush)
  end
end

---@alias lsp.ResultItem lsp.Symbol|lsp.CallHierarchyItem|{text?:string}
---@param client vim.lsp.Client
---@param results lsp.ResultItem[]
---@param opts? {default_uri?:string, filter?:(fun(result:lsp.ResultItem):boolean), text_with_file?:boolean}
function M.results_to_items(client, results, opts)
  opts = opts or {}
  local items = {} ---@type snacks.picker.finder.Item[]
  local last = {} ---@type table<snacks.picker.finder.Item, snacks.picker.finder.Item>

  ---@param result lsp.ResultItem
  ---@param parent snacks.picker.finder.Item
  local function add(result, parent)
    ---@type snacks.picker.finder.Item
    local item = {
      kind = M.symbol_kind(result.kind),
      parent = parent,
      detail = result.detail,
      name = result.name,
      text = "",
      range = result.range or result.selectionRange,
      item = result,
    }
    local uri = result.location and result.location.uri or result.uri or opts.default_uri
    local loc = result.location or { range = result.selectionRange or result.range, uri = uri }
    loc.uri = loc.uri or uri
    M.add_loc(item, loc, client)
    local text = table.concat({ M.symbol_kind(result.kind), result.name }, " ")
    if opts.text_with_file and item.file then
      text = text .. " " .. item.file
    end
    item.text = text

    if not opts.filter or opts.filter(result) then
      items[#items + 1] = item
      last[parent] = item
      parent = item
    end

    for _, child in ipairs(result.children or {}) do
      add(child, parent)
    end
    result.children = nil
  end

  local root = { text = "", root = true } ---@type snacks.picker.finder.Item
  ---@type snacks.picker.finder.Item
  for _, result in ipairs(results) do
    add(result, root)
  end
  for _, item in pairs(last) do
    item.last = true
  end

  return items
end

---@return boolean
local function has_pending_workspace_index()
  if has_uninitialized_clients() then
    return true
  end
  for _, client in ipairs(lsp_get_clients({ method = "workspace/symbol" })) do
    if client.progress and client.progress.pending and next(client.progress.pending) ~= nil then
      return true
    end
  end
  return false
end

local progress_watched = setmetatable({}, { __mode = "k" }) ---@type table<snacks.Picker, boolean>

---@param opts snacks.picker.lsp.symbols.Config
---@type snacks.picker.finder
function M.symbols(opts, ctx)
  if opts.keep_parents then
    ctx.picker.matcher.opts.keep_parents = true
    ctx.picker.matcher.opts.sort = false
  end
  local buf = ctx.filter.current_buf
  -- For unloaded buffers, load the buffer and
  -- refresh the picker on every LspAttach event
  -- for 10 seconds. Also defer to ensure the file is loaded by the LSP.
  if not vim.api.nvim_buf_is_loaded(buf) then
    local id = vim.api.nvim_create_autocmd("LspAttach", {
      buffer = buf,
      callback = vim.schedule_wrap(function()
        if ctx.picker:count() > 0 then
          return true
        end
        ctx.picker:find()
        vim.defer_fn(function()
          if ctx.picker:count() == 0 then
            ctx.picker:find()
          end
        end, 1000)
      end),
    })
    pcall(vim.fn.bufload, buf)
    vim.defer_fn(function()
      vim.api.nvim_del_autocmd(id)
    end, 10000)
    return function()
      ctx.async:sleep(2000)
    end
  end

  if opts.workspace and not progress_watched[ctx.picker] then
    progress_watched[ctx.picker] = true
    local id = vim.api.nvim_create_autocmd("LspProgress", {
      pattern = { "begin", "report", "end" },
      callback = function()
        if ctx.picker.closed then
          return true
        end
        if not ctx.picker.finder:running() and ctx.picker:count() == 0 then
          ctx.picker:find({ refresh = true })
        end
      end,
    })
    local on_close = ctx.picker.opts.on_close
    ctx.picker.opts.on_close = function(p)
      pcall(vim.api.nvim_del_autocmd, id)
      if on_close then
        on_close(p)
      end
    end
  end

  local bufmap = M.bufmap()
  local filter = opts.filter[vim.bo[buf].filetype]
  if filter == nil then
    filter = opts.filter.default
  end
  ---@param kind string?
  local function want(kind)
    kind = kind or "Unknown"
    return type(filter) == "boolean" or vim.tbl_contains(filter, kind)
  end

  local method = opts.workspace and "workspace/symbol" or "textDocument/documentSymbol"
  local p = opts.workspace and { query = ctx.filter.search }
    or { textDocument = vim.lsp.util.make_text_document_params(buf) }

  ---@async
  ---@param cb async fun(item: snacks.picker.finder.Item)
  local function request_items(cb)
    local add, flush = wrap_cb(cb)
    M.request(buf, method, function()
      return p
    end, function(client, result, params)
      local items = M.results_to_items(client, result, {
        default_uri = params.textDocument and params.textDocument.uri or nil,
        text_with_file = opts.workspace,
        filter = function(item)
          return want(M.symbol_kind(item.kind))
        end,
      })

      -- Fix sorting
      if not opts.workspace then
        table.sort(items, function(a, b)
          if a.pos[1] == b.pos[1] then
            return a.pos[2] < b.pos[2]
          end
          return a.pos[1] < b.pos[1]
        end)
      end

      -- fix last
      local last = {} ---@type table<snacks.picker.finder.Item, snacks.picker.finder.Item>
      for _, item in ipairs(items) do
        item.last = nil
        local parent = item.parent
        if parent then
          if last[parent] then
            last[parent].last = nil
          end
          last[parent] = item
          item.last = true
        end
      end

      for _, item in ipairs(items) do
        item.tree = opts.tree
        item.buf = bufmap[item.file]
        add(item)
      end
    end, flush)
  end

  if not opts.workspace then
    return request_items
  end

  ---@async
  ---@param cb async fun(item: snacks.picker.finder.Item)
  return function(cb)
    local seen = {} ---@type table<string, boolean>
    local emitted = 0

    ---@async
    ---@param item snacks.picker.finder.Item
    local function emit_new(item)
      local key = ("%s:%d:%d:%s:%s"):format(
        item.file or "",
        item.pos and item.pos[1] or 0,
        item.pos and item.pos[2] or 0,
        item.kind or "",
        item.name or ""
      )
      if not seen[key] then
        seen[key] = true
        emitted = emitted + 1
        cb(item)
      end
    end

    local dirty = false
    local autocmd_id ---@type number?
    local function cleanup()
      if autocmd_id then
        pcall(vim.api.nvim_del_autocmd, autocmd_id)
        autocmd_id = nil
      end
    end
    ctx.async:on("done", vim.schedule_wrap(cleanup))

    local pending = ctx.async:schedule(function()
      autocmd_id = vim.api.nvim_create_autocmd({ "LspProgress", "LspAttach" }, {
        callback = function()
          dirty = true
        end,
      })
      return has_pending_workspace_index()
    end)

    request_items(emit_new)

    local grace = (emitted == 0 and vim.trim(ctx.filter.search or "") == "") and 4 or 0
    if pending or emitted > 0 then
      grace = 0
    end
    local idle_ticks = 0
    local ticks = 0
    while (pending or grace > 0) and ticks < 120 and not ctx.async:aborted() do
      if not pending then
        grace = grace - 1
      end
      local was_pending = pending
      pending = ctx.async:defer(250, has_pending_workspace_index)
      ticks = ticks + 1
      if ctx.async:aborted() then
        break
      end
      if pending or emitted > 0 then
        grace = 0
      end
      if dirty or idle_ticks >= 4 or (was_pending and not pending) then
        dirty = false
        idle_ticks = 0
        request_items(emit_new)
        if emitted > 0 then
          grace = 0
        end
      else
        idle_ticks = idle_ticks + 1
      end
    end

    if dirty and not ctx.async:aborted() then
      request_items(emit_new)
    end
  end
end

---@param opts snacks.picker.lsp.Config
---@param filter snacks.picker.Filter
---@param incoming? boolean
function M.call_hierarchy(opts, filter, incoming)
  local method = ("callHierarchy/%sCalls"):format(incoming and "incoming" or "outgoing")
  local buf = filter.current_buf
  local win = filter.current_win

  ---@async
  ---@param cb async fun(item: snacks.picker.finder.Item)
  return function(cb)
    local add, flush = wrap_cb(cb)
    wait_for_clients(buf, "textDocument/prepareCallHierarchy")
    local requester = R.new()
    requester:request(buf, "textDocument/prepareCallHierarchy", function(client)
      return vim.lsp.util.make_position_params(win, client.offset_encoding)
    end, function(client, result)
      ---@cast result lsp.CallHierarchyItem[]
      for _, res in ipairs(result or {}) do
        requester:request(client, method, function()
          return { item = res }
        end, function(_, calls)
          ---@cast calls (lsp.CallHierarchyIncomingCall|lsp.CallHierarchyOutgoingCall)[]

          local call_items = {} ---@type lsp.CallHierarchyItem[]
          ---@param call lsp.CallHierarchyIncomingCall|lsp.CallHierarchyOutgoingCall
          for _, call in ipairs(calls) do
            if incoming then
              for _, range in ipairs(call.fromRanges or {}) do
                local from = vim.deepcopy(call.from)
                from.selectionRange = range or from.selectionRange
                table.insert(call_items, from)
              end
            else
              table.insert(call_items, call.to)
            end
          end

          local items = M.results_to_items(client, call_items, { default_uri = res.uri })
          vim.tbl_map(add, items)
        end)
      end
    end)
    requester:wait(flush)
  end
end

---@param opts snacks.picker.lsp.references.Config
---@type snacks.picker.finder
function M.references(opts, ctx)
  opts = opts or {}
  return M.get_locations(
    "textDocument/references",
    vim.tbl_deep_extend("force", opts, {
      context = { includeDeclaration = opts.include_declaration },
    }),
    ctx.filter
  )
end

---@param opts snacks.picker.lsp.Config
---@type snacks.picker.finder
function M.incoming_calls(opts, ctx)
  return M.call_hierarchy(opts, ctx.filter, true)
end

---@param opts snacks.picker.lsp.Config
---@type snacks.picker.finder
function M.outgoing_calls(opts, ctx)
  return M.call_hierarchy(opts, ctx.filter, false)
end

---@param opts snacks.picker.lsp.Config
---@type snacks.picker.finder
function M.definitions(opts, ctx)
  return M.get_locations("textDocument/definition", opts, ctx.filter)
end

---@param opts snacks.picker.lsp.Config
---@type snacks.picker.finder
function M.type_definitions(opts, ctx)
  return M.get_locations("textDocument/typeDefinition", opts, ctx.filter)
end

---@param opts snacks.picker.lsp.Config
---@type snacks.picker.finder
function M.implementations(opts, ctx)
  return M.get_locations("textDocument/implementation", opts, ctx.filter)
end

---@param opts snacks.picker.lsp.Config
---@type snacks.picker.finder
function M.declarations(opts, ctx)
  return M.get_locations("textDocument/declaration", opts, ctx.filter)
end

return M
