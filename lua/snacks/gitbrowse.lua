---@class snacks.gitbrowse
---@hide
---@overload fun(opts?: snacks.gitbrowse.Config)
local M = setmetatable({}, {
  __call = function(t, ...)
    return t.open(...)
  end,
})

---@class snacks.gitbrowse.Config
local defaults = {
  -- Handler to open the url in a browser
  ---@param url string
  open = function(url)
    if vim.fn.has("nvim-0.10") == 0 then
      require("lazy.util").open(url, { system = true })
      return
    end
    vim.ui.open(url)
  end,
  -- patterns to transform remotes to an actual URL
  -- stylua: ignore
  patterns = {
    { "^(https?://.*)%.git$"              , "%1" },
    { "^git@(.+):(.+)%.git$"              , "https://%1/%2" },
    { "^git@(.+):(.+)$"                   , "https://%1/%2" },
    { "^git@(.+)/(.+)$"                   , "https://%1/%2" },
    { "^ssh://git@(.*)$"                  , "https://%1" },
    { "^ssh://([^:/]+)(:%d+)/(.*)$"       , "https://%1/%3" },
    { "^ssh://([^/]+)/(.*)$"              , "https://%1/%2" },
    { "ssh%.dev%.azure%.com/v3/(.*)/(.*)$", "dev.azure.com/%1/_git/%2" },
    { "^https://%w*@(.*)"                 , "https://%1" },
    { "^git@(.*)"                         , "https://%1" },
    { ":%d+"                              , "" },
    { "%.git$"                            , "" },
  },
}

---@private
---@param remote string
---@param opts? snacks.gitbrowse.Config
function M.get_url(remote, opts)
  opts = Snacks.config.get("gitbrowse", defaults, opts)
  local ret = remote
  for _, pattern in ipairs(opts.patterns) do
    ret = ret:gsub(pattern[1], pattern[2])
  end
  return ret:find("https://") == 1 and ret or ("https://%s"):format(ret)
end

---@param opts? snacks.gitbrowse.Config
function M.open(opts)
  opts = Snacks.config.get("gitbrowse", defaults, opts)
  local proc = vim.system({ "git", "remote", "-v" }, { text = true }):wait()
  if proc.code ~= 0 then
    return Snacks.notify.error("Failed to get git remotes", { title = "Git Browse" })
  end
  local lines = vim.split(proc.stdout, "\n")

  proc = vim.system({ "git", "rev-parse", "--abbrev-ref", "HEAD" }):wait()
  if proc.code ~= 0 then
    return Snacks.notify.error("Failed to get current branch", { title = "Git Browse" })
  end
  local branch = proc.stdout:gsub("\n", "")

  local remotes = {} ---@type {name:string, url:string}[]

  for _, line in ipairs(lines) do
    local name, remote = line:match("(%S+)%s+(%S+)%s+%(fetch%)")
    if name and remote then
      local url = M.get_url(remote, opts)
      if url:find("github") and branch and branch ~= "master" and branch ~= "main" then
        url = ("%s/tree/%s/"):format(url, branch)
      elseif branch == "main" then
        url = ("%s/tree/main/"):format(url)
      elseif branch == "master" then
        url = ("%s/tree/master/"):format(url)
      end
      if url then
        table.insert(remotes, {
          name = name,
          url = url,
          file = vim.system({ "git", "ls-files", "--full-name", vim.fn.expand("%") }):wait().stdout:gsub("\n", ""),
        })
      end
    end
  end

  local function open(remote)
    if remote then
      Snacks.notify(("Opening [%s](%s)"):format(remote.name, remote.url), { title = "Git Browse" })
      opts.open(remote.url .. remote.file)
    end
  end

  if #remotes == 0 then
    return Snacks.notify.error("No git remotes found", { title = "Git Browse" })
  elseif #remotes == 1 then
    return open(remotes[1])
  end

  vim.ui.select(remotes, {
    prompt = "Select remote to browse",
    format_item = function(item)
      return item.name .. (" "):rep(8 - #item.name) .. " 🔗 " .. item.url
    end,
  }, open)
end

return M
