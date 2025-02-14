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

local function sqlite3_lib()
  local opts = Snacks.picker.config.get()
  if opts.db.sqlite3_path then
    return opts.db.sqlite3_path
  end
  if jit.os ~= "Windows" then
    return "sqlite3"
  end
  local sqlite_path = vim.fn.stdpath("cache") .. "\\sqlite3.dll"
  if vim.fn.filereadable(sqlite_path) == 0 then
    Snacks.notify("Downloading `sqlite3.dll`")
    local url = ("https://www.sqlite.org/2025/sqlite-dll-win-%s-3480000.zip"):format(jit.arch)
    local out = vim.fn.system({
      "powershell",
      "-Command",
      [[
        $url = "]] .. url .. [[";
        $zipPath = "$env:TEMP\sqlite.zip";
        $extractPath = "$env:TEMP\sqlite";
        Invoke-WebRequest -Uri $url -OutFile $zipPath;
        Add-Type -AssemblyName System.IO.Compression.FileSystem;
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $extractPath);

        $dllPath = "$extractPath\sqlite3.dll";
        if (Test-Path $dllPath) {
            Move-Item -Path $dllPath -Destination "]] .. sqlite_path .. [[" -Force;
        } else {
            Write-Host "sqlite3.dll not found at $dllPath";
        }
      ]],
    })
    if vim.v.shell_error ~= 0 then
      Snacks.notify.error("Failed to download `sqlite3.dll`:\n" .. out)
    else
      Snacks.notify("Downloaded `sqlite3.dll`")
    end
  end
  return sqlite_path
end

local sqlite = ffi.load(sqlite3_lib())

---@alias sqlite3* ffi.cdata*
---@alias sqlite3_stmt* ffi.cdata*

---@class snacks.picker.db
---@field type type
---@field db sqlite3*
---@field handle ffi.cdata*
---@field insert snacks.picker.db.Query
---@field select snacks.picker.db.Query
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

---@class snacks.picker.db.Query
---@field stmt sqlite3_stmt*
---@field handle ffi.cdata*
local Query = {}
Query.__index = Query

function Query.new(db, query)
  local self = setmetatable({}, Query)
  local stmt = ffi.new("sqlite3_stmt*[1]")
  local code = sqlite.sqlite3_prepare_v2(db.db, query, #query, stmt, nil) --[[@as number]]
  if code ~= 0 then
    error("Failed to prepare statement: " .. code)
  end
  self.handle = stmt
  ffi.gc(stmt, function()
    self:close()
  end)
  self.stmt = stmt[0]
  return self
end

function Query:reset()
  return sqlite.sqlite3_reset(self.stmt)
end

---@param binds? any[]
function Query:exec(binds)
  self:reset()
  for i, value in ipairs(binds or {}) do
    if bind(self.stmt, i, value) ~= 0 then
      error(("Failed to bind %d=%s"):format(i, value))
    end
  end
  return self:step()
end

---@return number
function Query:step()
  return sqlite.sqlite3_step(self.stmt)
end

function Query:close()
  if self.stmt then
    sqlite.sqlite3_finalize(self.stmt)
    self.stmt = nil
  end
end

function Query:bind(idx, value)
  return bind(self.stmt, idx, value)
end

---@param idx? number
---@param value_type type
function Query:col(value_type, idx)
  idx = idx or 0
  local ret = ffi.string(sqlite.sqlite3_column_text(self.stmt, idx))
  if value_type == "string" then
    return ret
  elseif value_type == "number" then
    return tonumber(ret)
  elseif value_type == "boolean" then
    return ret == "1"
  end
  error("Unsupported value type: " .. value_type)
end

function M.new(path, value_type)
  local self = setmetatable({}, M)
  local handle = ffi.new("sqlite3*[1]")
  if sqlite.sqlite3_open(path, handle) ~= 0 then
    error("Failed to open database: " .. path)
  end

  self.handle = handle
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
function M:prepare(query)
  return Query.new(self, query)
end

function M:close()
  if self.db then
    sqlite.sqlite3_close(self.db)
    self.db = nil
    self.handle = nil
  end
end

function M:set(key, value)
  if self.insert:exec({ key, value }) ~= 101 then -- 101 == SQLITE_DONE
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

---@param key string
function M:get(key)
  if self.select:exec({ key }) == 100 then -- 100 == SQLITE_ROW
    return self.select:col(self.type)
  end
end

function M:count()
  local query = self:prepare("SELECT COUNT(*) FROM data;")
  if query:exec() == 100 then
    return query:col("number")
  end
end

function M:get_all()
  local query = self:prepare("SELECT key, value FROM data;")
  local ret = {} ---@type table<string, any>
  local code = query:exec()
  while code == 100 do -- 100 == SQLITE_ROW
    local k = query:col("string", 0) -- key is always a string
    local v = query:col(self.type, 1) -- value type is whatever you set
    ret[k] = v
    code = query:step()
  end
  query:close()
  return ret
end

return M
