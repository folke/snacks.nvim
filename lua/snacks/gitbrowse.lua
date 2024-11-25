---@class snacks.gitbrowse
---@overload fun(opts?: snacks.gitbrowse.Config)
local M = setmetatable({}, {
  __call = function(t, ...)
    return t.open(...)
  end,
})

local uv = vim.uv or vim.loop

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
  ---@type "repo" | "branch" | "file"
  what = "file", -- what to open. not all remotes support all types
  -- patterns to transform remotes to an actual URL
  -- stylua: ignore
  remote_patterns = {
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
  url_patterns = {
    ["github%.com"] = {
      branch = "/tree/{branch}",
      file = "/blob/{branch}/{file}#L{line}",
    },
    ["gitlab%.com"] = {
      branch = "/-/tree/{branch}",
      file = "/-/blob/{branch}/{file}#L{line}",
    },
    ["bitbucket%.org"] = {
      branch = "/src/{branch}",
      file = "/src/{branch}/{file}#lines-{line}",
      commit = "/commits/{commit}",
    },
  },
}

---@private
---@param remote string
---@param opts? snacks.gitbrowse.Config
function M.get_repo(remote, opts)
  opts = Snacks.config.get("gitbrowse", defaults, opts)
  local ret = remote
  for _, pattern in ipairs(opts.remote_patterns) do
    ret = ret:gsub(pattern[1], pattern[2]) --[[@as string]]
  end
  return ret:find("https://") == 1 and ret or ("https://%s"):format(ret)
end

---@param repo string
---@param opts? snacks.gitbrowse.Config
function M.get_url(repo, opts)
  opts = Snacks.config.get("gitbrowse", defaults, opts)
  for remote, patterns in pairs(opts.url_patterns) do
    if repo:find(remote) then
      return patterns[opts.what] and (repo .. patterns[opts.what]) or repo
    end
  end
  return repo
end

---@param cmd string[]
---@param err string
local function system(cmd, err)
  local proc = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    Snacks.notify.error({ err, proc }, { title = "Git Browse" })
    error(err)
  end
  return vim.split(vim.trim(proc), "\n")
end

---@param opts? snacks.gitbrowse.Config
function M.open(opts)
  pcall(M._open, opts) -- errors are handled with notifications
end

---@param opts? snacks.gitbrowse.Config
function M._open(opts)
  opts = Snacks.config.get("gitbrowse", defaults, opts)
  local file = vim.api.nvim_buf_get_name(0) ---@type string?
  file = file and (uv.fs_stat(file) or {}).type == "file" and vim.fs.normalize(file) or nil
  local cwd = file and vim.fn.fnamemodify(file, ":h") or vim.fn.getcwd()
  local fields = {
    branch = system({ "git", "-C", cwd, "rev-parse", "--abbrev-ref", "HEAD" }, "Failed to get current branch")[1],
    file = file and system({ "git", "-C", cwd, "ls-files", "--full-name", file }, "Failed to get git file path")[1],
    line = nil,
  }

  -- Get visual selection range if in visual mode
  if vim.fn.mode() == "v" or vim.fn.mode() == "V" then
    local start_line = vim.fn.line("v")
    local end_line = vim.fn.line(".")
    -- Ensure start_line is always the smaller number
    if start_line > end_line then
      start_line, end_line = end_line, start_line
    end
    fields.line = file and start_line .. "-L" .. end_line
  else
    fields.line = file and vim.fn.line(".")
  end

  opts.what = opts.what == "file" and not fields.file and "branch" or opts.what
  opts.what = opts.what == "branch" and not fields.branch and "repo" or opts.what

  local remotes = {} ---@type {name:string, url:string}[]

  for _, line in ipairs(system({ "git", "-C", cwd, "remote", "-v" }, "Failed to get git remotes")) do
    local name, remote = line:match("(%S+)%s+(%S+)%s+%(fetch%)")
    if name and remote then
      local repo = M.get_repo(remote, opts)
      if repo then
        table.insert(remotes, {
          name = name,
          url = M.get_url(repo, opts):gsub("(%b{})", function(key)
            return fields[key:sub(2, -2)] or key
          end),
        })
      end
    end
  end

  local function open(remote)
    if remote then
      Snacks.notify(("Opening [%s](%s)"):format(remote.name, remote.url), { title = "Git Browse" })
      opts.open(remote.url)
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
