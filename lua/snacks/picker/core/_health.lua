local M = {}

---@private
function M.health()
  local config = Snacks.picker.config.get()
  if Snacks.config.get("picker", {}).enabled and config.ui_select then
    if vim.ui.select == Snacks.picker.select then
      Snacks.health.ok("`vim.ui.select` is set to `Snacks.picker.select`")
    else
      Snacks.health.error("`vim.ui.select` is not set to `Snacks.picker.select`")
    end
  else
    Snacks.health.warn("`vim.ui.select` for `Snacks.picker` is not enabled")
  end
  for _, lang in ipairs({ "regex" }) do
    local has_lang = pcall(vim.treesitter.language.add, lang)
    if has_lang then
      Snacks.health.ok("Treesitter language `" .. lang .. "` is available")
    else
      Snacks.health.error("Treesitter language `" .. lang .. "` is not available")
    end
  end
  local is_win = jit.os:find("Windows")
  local function have(tool)
    if vim.fn.executable(tool) == 1 then
      local version = vim.fn.system(tool .. " --version") or ""
      version = vim.trim(vim.split(version, "\n")[1])
      Snacks.health.ok("'" .. tool .. "' `" .. version .. "`")
      return true
    end
  end
  local required = { { "git" }, { "rg" }, { "fd", "fdfind", not is_win and "find" or nil } }
  for _, tools in ipairs(required) do
    local found = false
    for _, tool in ipairs(tools) do
      if have(tool) then
        found = true
      end
    end
    if not found then
      Snacks.health.error("None of the tools found: " .. table.concat(
        vim.tbl_map(function()
          return "'" .. tostring(_) .. "'"
        end, tools),
        ", "
      ))
    end
  end
end

return M
