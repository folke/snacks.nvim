---@class snacks.picker.gh.Item
---@field opts snacks.gh.api.Config
local M = {}

local time_fields = {
  created = "createdAt",
  updated = "updatedAt",
  closed = "closedAt",
  merged = "mergedAt",
  submitted = "submittedAt",
}

---@param s? string
---@return number?
local function ts(s)
  if not s then
    return nil
  end
  local year, month, day, hour, min, sec = s:match("^(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)Z$")
  if not year then
    return
  end
  local t = os.time({
    year = assert(tonumber(year), "invalid year in timestamp: " .. s),
    month = assert(tonumber(month), "invalid month in timestamp: " .. s),
    day = assert(tonumber(day), "invalid day in timestamp: " .. s),
    hour = assert(tonumber(hour), "invalid hour in timestamp: " .. s),
    min = assert(tonumber(min), "invalid minute in timestamp: " .. s),
    sec = assert(tonumber(sec), "invalid second in timestamp: " .. s),
    isdst = false,
  })
  -- Calculate UTC offset
  local now = os.time()
  local utc_date = os.date("!*t", now) --[[@as osdate]]
  utc_date.isdst = false
  return t + os.difftime(now, os.time(utc_date))
end

---@param obj {body?:string}
local function fix(obj)
  obj.body = obj.body and obj.body:gsub("\r\n", "\n") or nil
  for key, field in pairs(time_fields) do
    ---@diagnostic disable-next-line: no-unknown, assign-type-mismatch
    obj[key] = obj[key] or ts(obj[field] or obj[field:gsub("At", "_at")])
  end
end

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
    local repo = M.get_repo(item.url)
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
  vim.tbl_map(fix, item.comments or {})
  self.pendingReview = nil
  for _, review in ipairs(item.reviews or {}) do
    fix(review)
    if review.state == "PENDING" and review.viewerDidAuthor then
      self.pendingReview = review
    end
    vim.tbl_map(fix, review.comments or {})
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

---@param url string
function M.get_repo(url)
  local path = url:find("^http") and url:gsub("^https?://[^/]+/", "") or url:gsub("^[^/]+/", "")
  return path:match("([^/]+/[^/]+)") --[[@as string?]]
end

return M
