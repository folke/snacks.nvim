---@class snacks.picker.gh.Item
---@field opts snacks.gh.api.Config
local M = {}

---@param s? string
local function ts(s)
  return (s and vim.fn.strptime("%Y-%m-%dT%H:%M:%SZ", s)) or nil
end

local time_fields = { created = "createdAt", updated = "updatedAt", closed = "closedAt", merged = "mergedAt" }

---@param item snacks.gh.Item
---@param opts snacks.gh.api.Config
function M.new(item, opts)
  if getmetatable(item) == M then
    return item --[[@as snacks.picker.gh.Item]]
  end
  local self = setmetatable({}, M) --[[@as snacks.picker.gh.Item]]
  for k, v in pairs(item) do
    if v == vim.NIL then
      item[k] = nil
    end
  end
  self.item = item
  self.opts = opts
  self.type = opts.type
  self.repo = opts.repo
  self.fields = {}
  for _, field in ipairs(opts.fields or {}) do
    self.fields[field] = true
  end
  self:update()
  return self --[[@as snacks.picker.gh.Item]]
end

---@param item any
function M.is(item)
  return getmetatable(item) == M
end

function M:__index(key)
  if time_fields[key] then
    return ts(self.item[time_fields[key]])
  end
  return rawget(M, key) or rawget(self.item, key)
end

---@param fields string[]
function M:need(fields)
  ---@param field string
  return vim.tbl_filter(function(field)
    return not self.fields[field]
  end, fields)
end

---@param data? table<string, any>
---@param fields? string[]
function M:update(data, fields)
  for k, v in pairs(data or {}) do
    ---@diagnostic disable-next-line: no-unknown
    self.item[k] = v ~= vim.NIL and v or nil
  end
  local item = self.item
  for _, field in ipairs(fields or {}) do
    if data and data[field] == nil then
      self.item[field] = nil
    end
    self.fields[field] = true
  end
  if not self.repo and item.url then
    local repo = item.url:match("github%.com/([^/]+/[^/]+)/")
    if repo then
      self.repo = repo
    end
  end
  if self.repo then
    self.uri = ("gh://%s/%s/%s"):format(self.repo, self.type, tostring(item.number or ""))
    self.file = self.uri
  end
  self.author = item.author and item.author.login or nil
  self.hash = item.number and ("#" .. tostring(item.number)) or nil
  self.state = item.state and item.state:lower() or nil
  self.status = self.state
  self.state_reason = item.stateReason and item.stateReason:lower() or nil
  self.draft = item.isDraft
  self.label = item.labels
      and table.concat(
        ---@param label snacks.gh.Label
        vim.tbl_map(function(label)
          return label.name
        end, item.labels),
        ","
      )
    or nil
  self.body = item.body and item.body:gsub("\r\n", "\n") or nil
  for _, comment in ipairs(item.comments or {}) do
    comment.body = comment.body and comment.body:gsub("\r\n", "\n") or nil
    setmetatable(comment, {
      __index = function(tbl, key)
        if time_fields[key] then
          return ts(tbl[time_fields[key]])
        end
      end,
    })
  end
  if item.reactionGroups then
    self.reactions = {}
    for _, reaction in ipairs(item.reactionGroups) do
      table.insert(
        self.reactions,
        { content = reaction.content:lower(), count = reaction.users and reaction.users.totalCount or 0 }
      )
    end
  end
  if self.opts.transform then
    self.opts.transform(self)
  end
  self.text = Snacks.picker.util.text(self.item, self.opts.text or self.opts.fields or {})
end

---@param item snacks.gh.api.View
function M.to_uri(item)
  if item.uri then
    return item.uri
  end
  return ("gh://%s/%s/%s"):format(item.repo or "", assert(item.type), tostring(assert(item.number)))
end

return M
