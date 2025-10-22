---@diagnostic disable: missing-fields
local M = {}

---@param cwd string
function M.update(cwd)
  local Tree = require("snacks.explorer.tree")
  local node = Tree:find(cwd)

  local snapshot = Tree:snapshot(node, { "severity" })

  Tree:walk(node, function(n)
    n.severity = nil
  end, { all = true })

  local diags = vim.diagnostic.get()

  ---@param path string
  ---@param diag vim.Diagnostic
  local function add(path, diag)
    local n = Tree:find(path)
    local severity = tonumber(diag.severity) or vim.diagnostic.severity.INFO
    n.severity = math.min(n.severity or severity, severity)
  end

  for _, diag in ipairs(diags) do
    local path = diag.bufnr and vim.api.nvim_buf_get_name(diag.bufnr)
    path = path and path ~= "" and svim.fs.normalize(path) or nil
    if path then
      add(path, diag)
      add(cwd, diag)
      for dir in Snacks.picker.util.parents(path, cwd) do
        add(dir, diag)
      end
    end
  end

  return Tree:changed(node, snapshot)
end

return M
