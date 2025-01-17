local ffi = require("ffi")

ffi.cdef([[
  typedef struct sqlite3 sqlite3;
  typedef struct sqlite3_stmt sqlite3_stmt;

  int sqlite3_open(const char *filename, sqlite3 **ppDb);
  int sqlite3_close(sqlite3*);
  int sqlite3_exec(
    sqlite3*, const char *sql, int (*callback)(void*,int,char**,char**), void*, char **errmsg);
  int sqlite3_prepare_v2(
    sqlite3*, const char *zSql, int nByte, sqlite3_stmt **ppStmt, const char **pzTail);
  int sqlite3_reset(sqlite3_stmt*);
  int sqlite3_step(sqlite3_stmt*);
  int sqlite3_finalize(sqlite3_stmt*);
  int sqlite3_bind_text(sqlite3_stmt*, int, const char*, int n, void(*)(void*));
  int sqlite3_bind_int64(sqlite3_stmt*, int, long long);
  const unsigned char *sqlite3_column_text(sqlite3_stmt*, int);
  long long sqlite3_column_int64(sqlite3_stmt*, int);
]])

local sqlite = ffi.load("sqlite3")

---@alias sqlite3* ffi.cdata*
---@alias sqlite3_stmt* ffi.cdata*

---@class snacks.picker.db
---@field type type
---@field db sqlite3*
---@field insert sqlite3_stmt*
---@field select sqlite3_stmt*
local M = {}
M.__index = M

---@param stmt ffi.cdata*
---@param idx number
---@param value any
---@param value_type? type
local function bind(stmt, idx, value, value_type)
  value_type = value_type or type(value)
  if value_type == "string" then
    return sqlite.sqlite3_bind_text(stmt, idx, value, #value, nil)
  elseif value_type == "number" then
    return sqlite.sqlite3_bind_int64(stmt, idx, value)
  elseif value_type == "boolean" then
    return sqlite.sqlite3_bind_int64(stmt, idx, value and 1 or 0)
  else
    error("Unsupported value type: " .. type(value) .. " (" .. tostring(value) .. ")")
  end
end

function M.new(path, value_type)
  local self = setmetatable({}, M)
  local handle = ffi.new("sqlite3*[1]")
  if sqlite.sqlite3_open(path, handle) ~= 0 then
    error("Failed to open database: " .. path)
  end

  self.db = handle[0]
  self.type = value_type or "number"
  self:exec("PRAGMA journal_mode=WAL")

  -- Create the table if it doesn't exist
  self:exec(([[
      CREATE TABLE IF NOT EXISTS data (
        key TEXT PRIMARY KEY,
        value %s NOT NULL
      );
    ]]):format(({
    number = "INTEGER",
    string = "TEXT",
    boolean = "INTEGER",
  })[self.type]))

  self.insert = self:prepare("INSERT OR REPLACE INTO data (key, value) VALUES (?, ?);")
  self.select = self:prepare("SELECT value FROM data WHERE key = ?;")

  ffi.gc(handle, function()
    self:close()
  end)

  return self
end

---@param query string
---@return sqlite3_stmt*
function M:prepare(query)
  local stmt = ffi.new("sqlite3_stmt*[1]")
  if sqlite.sqlite3_prepare_v2(self.db, query, #query, stmt, nil) ~= 0 then
    error("Failed to prepare statement")
  end
  ffi.gc(stmt, function()
    sqlite.sqlite3_finalize(stmt[0])
  end)
  return stmt[0]
end

function M:close()
  if self.db then
    sqlite.sqlite3_close(self.db)
    self.db = nil
  end
end

function M:set(key, value)
  local stmt = self.insert
  sqlite.sqlite3_reset(stmt)
  -- Bind parameters and execute
  if bind(stmt, 1, key) ~= 0 then
    error("Failed to bind key")
  end
  if bind(stmt, 2, value, self.type) ~= 0 then
    error("Failed to bind value")
  end
  if sqlite.sqlite3_step(stmt) ~= 101 then -- 101 == SQLITE_DONE
    error("Failed to execute insert statement")
  end
end

---@param query string
function M:exec(query)
  query = query:sub(-1) ~= ";" and query .. ";" or query
  local errmsg = ffi.new("char*[1]")
  if sqlite.sqlite3_exec(self.db, query, nil, nil, errmsg) ~= 0 then
    error(ffi.string(errmsg[0]))
  end
end

function M:begin()
  self:exec("BEGIN")
end

function M:commit()
  self:exec("COMMIT")
end

function M:rollback()
  self:exec("ROLLBACK")
end

function M:get(key)
  local stmt = self.select
  sqlite.sqlite3_reset(stmt)
  bind(stmt, 1, key)

  local ret
  if sqlite.sqlite3_step(stmt) == 100 then -- 100 == SQLITE_ROW
    ret = ffi.string(sqlite.sqlite3_column_text(stmt, 0))
    if self.type == "number" then
      ret = tonumber(ret)
    elseif self.type == "boolean" then
      ret = ret == "1"
    end
  end
  return ret
end

return M
