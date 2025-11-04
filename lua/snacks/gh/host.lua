---@class snacks.gh.host
local M = {}

--- Cached host value to avoid accessing vim.env in callbacks
local cached_host = nil

--- Detect GitHub host from git remote URLs (safe for callbacks)
--- Supports: https://, http://, git@, git://, ssh://
---@return string?
local function detect_host_from_git()
  -- Use io.popen instead of vim.fn.system for callback safety
  -- io.popen is standard Lua and safe in all contexts (main thread, callbacks, fast events)
  local handle = io.popen("git config --get remote.origin.url 2>/dev/null")
  if not handle then
    return nil
  end

  local origin = handle:read("*a") or ""
  handle:close()

  if origin == "" then
    return nil
  end

  origin = origin:gsub("\n", "")

  -- Match various git URL formats:
  -- https://host/ or http://host/
  -- git@host:
  -- ssh://git@host/ or ssh://user@host/
  -- git://host/
  local host = origin:match("^https?://([^/]+)/")     -- http(s)://host/
    or origin:match("^git@([^:]+):")                  -- git@host:
    or origin:match("^ssh://[^@]+@([^/]+)/")          -- ssh://git@host/
    or origin:match("^git://([^/]+)/")                -- git://host/

  -- Filter out github.com since that's the default anyway
  if host and host ~= "github.com" then
    return host
  end
  return nil
end

--- Get the configured GitHub host
--- Priority: explicit config > auto-detect from git > env var > github.com
--- Uses os.getenv (safe in all contexts) vs vim.env (unsafe in fast event contexts)
---
--- NOTE: The host is cached on first access and won't update if you switch
--- directories to a different repository. This is a known limitation to avoid
--- repeated git calls. The cache is cleared on config reload.
--- If you need to force a re-detection, restart Neovim or reload the gh plugin.
---@return string
function M.get()
  if not cached_host then
    local config = require("snacks.gh").config()
    -- Priority: explicit config > auto-detect from git > env var > github.com
    cached_host = config.host or detect_host_from_git() or os.getenv("GH_HOST") or "github.com"
  end
  return cached_host
end

--- Clear the cached host value
--- Useful for tests, config reloads, or switching repositories
--- Called automatically when gh config is loaded/reloaded
function M.clear_cache()
  cached_host = nil
end

--- Escape special characters for use in Lua patterns
--- All Lua pattern magic characters: ^ $ ( ) . % [ ] * + - ?
--- Replaces each with %X (escaped version)
---@param str string
---@return string
function M.escape_pattern(str)
  return str:gsub("[%-%.%+%[%]%(%)%$%^%%%?%*]", "%%%1")
end

return M
