local Async = require("snacks.picker.util.async")

local M = {}

local islist = vim.islist or vim.tbl_islist

---@class snacks.picker
---@field lsp_definitions? fun(opts?: snacks.picker.lsp.Config):snacks.Picker
---@field lsp_implementations? fun(opts?: snacks.picker.lsp.Config):snacks.Picker
---@field lsp_declarations? fun(opts?: snacks.picker.lsp.Config):snacks.Picker
---@field lsp_type_definitions? fun(opts?: snacks.picker.lsp.Config):snacks.Picker
---@field lsp_references? fun(opts?: snacks.picker.lsp.references.Config):snacks.Picker
---@field lsp_symbols? fun(opts?: snacks.picker.lsp.symbols.Config):snacks.Picker

---@alias lsp.Symbol lsp.SymbolInformation|lsp.DocumentSymbol
---@alias lsp.Loc lsp.Location|lsp.LocationLink

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
  return kinds[kind]
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
  local methods = { "request", "supports_method", "cancel_request" }
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
    ---@diagnostic disable-next-line: deprecated
  end, (vim.lsp.get_clients or vim.lsp.get_active_clients)({ bufnr = buf }))
  ---@param client vim.lsp.Client
  return vim.tbl_filter(function(client)
    return client:supports_method(method, buf)
    ---@diagnostic disable-next-line: deprecated
  end, clients)
end

---@param buf number
---@param method string
---@param params fun(client:vim.lsp.Client):table
---@param cb fun(client:vim.lsp.Client, result:table, params:table)
---@async
function M.request(buf, method, params, cb)
  local async = Async.running()
  local cancel = {} ---@type fun()[]

  async:on("abort", function()
    for _, c in ipairs(cancel) do
      c()
    end
  end)
  vim.schedule(function()
    local clients = M.get_clients(buf, method)
    local remaining = #clients
    for _, client in ipairs(clients) do
      local p = params(client)
      local status, request_id = client:request(method, p, function(_, result)
        if result then
          cb(client, result, p)
        end
        remaining = remaining - 1
        if remaining == 0 then
          async:resume()
        end
      end)
      if status and request_id then
        table.insert(cancel, function()
          client:cancel_request(request_id)
        end)
      end
    end
  end)

  async:suspend()
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

---@param method string
---@param opts snacks.picker.lsp.Config|{context?:lsp.ReferenceContext}
---@param filter snacks.picker.Filter
function M.get_locations(method, opts, filter)
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_get_current_buf()
  local fname = vim.api.nvim_buf_get_name(buf)
  fname = vim.fs.normalize(fname)
  local cursor = vim.api.nvim_win_get_cursor(win)

  ---@async
  ---@param cb async fun(item: snacks.picker.finder.Item)
  return function(cb)
    M.request(buf, method, function(client)
      local params = vim.lsp.util.make_position_params(win, client.offset_encoding)
      ---@diagnostic disable-next-line: inject-field
      params.context = opts.context
      return params
    end, function(client, result)
      result = result or {}
      -- Result can be a single item or a list of items
      result = vim.tbl_isempty(result) and {} or islist(result) and result or { result }

      local items = vim.lsp.util.locations_to_items(result or {}, client.offset_encoding)
      M.fix_locs(items)

      if not opts.include_current then
        ---@param item vim.quickfix.entry
        items = vim.tbl_filter(function(item)
          if item.filename ~= fname then
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

      local done = {} ---@type table<string, boolean>
      for _, loc in ipairs(items) do
        ---@type snacks.picker.finder.Item
        local item = {
          text = loc.filename .. " " .. loc.text,
          buf = loc.bufnr,
          file = loc.filename,
          pos = { loc.lnum, loc.col - 1 },
          end_pos = loc.end_lnum and loc.end_col and { loc.end_lnum, loc.end_col - 1 } or nil,
          line = loc.text,
        }
        local loc_key = loc.filename .. ":" .. loc.lnum
        if filter:match(item) and not (done[loc_key] and opts.unique_lines) then
          ---@diagnostic disable-next-line: await-in-sync
          cb(item)
          done[loc_key] = true
        end
      end
    end)
  end
end

---@alias lsp.ResultItem lsp.Symbol|lsp.CallHierarchyItem|{text?:string}
---@param client vim.lsp.Client
---@param results lsp.ResultItem[]
---@param opts? {default_uri?:string, filter?:(fun(result:lsp.ResultItem):boolean), text_with_file?:boolean}
function M.results_to_items(client, results, opts)
  opts = opts or {}
  local items = {} ---@type snacks.picker.finder.Item[]
  local locs = {} ---@type lsp.Loc[]

  ---@param result lsp.ResultItem
  local function process(result)
    local uri = result.location and result.location.uri or result.uri or opts.default_uri
    local loc = result.location or { range = result.selectionRange or result.range, uri = uri }
    loc.uri = loc.uri or uri
    if not loc.uri then
      assert(loc.uri, "missing uri in result:\n" .. vim.inspect(result))
    end
    if not opts.filter or opts.filter(result) then
      locs[#locs + 1] = loc
    end
    for _, child in ipairs(result.children or {}) do
      process(child)
    end
  end

  for _, result in ipairs(results) do
    process(result)
  end

  local last = {} ---@type table<snacks.picker.finder.Item, snacks.picker.finder.Item>
  ---@param result lsp.ResultItem
  ---@param parent snacks.picker.finder.Item
  local function add(result, parent)
    ---@type snacks.picker.finder.Item
    local item = {
      kind = M.symbol_kind(result.kind),
      parent = parent,
      depth = (parent.depth or 0) + 1,
      detail = result.detail,
      name = result.name,
      text = "",
    }
    local uri = result.location and result.location.uri or result.uri or opts.default_uri
    local loc = result.location or { range = result.selectionRange or result.range, uri = uri }
    loc.uri = loc.uri or uri
    M.add_loc(item, loc, client)
    local text = table.concat({ M.symbol_kind(result.kind), result.name, result.detail or "" }, " ")
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

  local root = { depth = 0, text = "" } ---@type snacks.picker.finder.Item
  ---@type snacks.picker.finder.Item
  for _, result in ipairs(results) do
    add(result, root)
  end
  for _, item in pairs(last) do
    item.last = true
  end

  return items
end

---@param opts snacks.picker.lsp.symbols.Config
---@param filt snacks.picker.Filter
function M.symbols(opts, filt)
  local buf = filt.current_buf
  local ft = vim.bo[buf].filetype
  local filter = opts.filter[ft]
  if filter == nil then
    filter = opts.filter.default
  end
  ---@param kind string?
  local function want(kind)
    kind = kind or "Unknown"
    return type(filter) == "boolean" or vim.tbl_contains(filter, kind)
  end

  local method = opts.workspace and "workspace/symbol" or "textDocument/documentSymbol"
  local p = opts.workspace and { query = filt.search } or { textDocument = vim.lsp.util.make_text_document_params(buf) }

  ---@async
  ---@param cb async fun(item: snacks.picker.finder.Item)
  return function(cb)
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
      for _, item in ipairs(items) do
        item.hierarchy = opts.hierarchy
        ---@diagnostic disable-next-line: await-in-sync
        cb(item)
      end
    end)
  end
end

---@param opts snacks.picker.lsp.references.Config
---@type snacks.picker.finder
function M.references(opts, filter)
  opts = opts or {}
  return M.get_locations(
    "textDocument/references",
    vim.tbl_deep_extend("force", opts, {
      context = { includeDeclaration = opts.include_declaration },
    }),
    filter
  )
end

---@param opts snacks.picker.lsp.Config
---@type snacks.picker.finder
function M.definitions(opts, filter)
  return M.get_locations("textDocument/definition", opts, filter)
end

---@param opts snacks.picker.lsp.Config
---@type snacks.picker.finder
function M.type_definitions(opts, filter)
  return M.get_locations("textDocument/typeDefinition", opts, filter)
end

---@param opts snacks.picker.lsp.Config
---@type snacks.picker.finder
function M.implementations(opts, filter)
  return M.get_locations("textDocument/implementation", opts, filter)
end

---@param opts snacks.picker.lsp.Config
---@type snacks.picker.finder
function M.declarations(opts, filter)
  return M.get_locations("textDocument/declaration", opts, filter)
end

return M
