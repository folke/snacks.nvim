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

  Snacks.health.has_lang("regex")

  Snacks.health.have_tool("git")

  local have_rg = Snacks.health.have_tool("rg")
  if not have_rg then
    Snacks.health.error("'rg' is required for `Snacks.picker.grep()`")
  else
    Snacks.health.ok("`Snacks.picker.grep()` is available")
  end

  local have_fd, version_fd = Snacks.health.have_tool({
    { cmd = { "fd", "fdfind" }, version = "v8.4" },
  })
  local have_find = have_fd
    or (jit.os:find("Windows") == nil and Snacks.health.have_tool({
      { cmd = "find", version = false },
    }))
  if have_rg or have_fd or have_find then
    Snacks.health.ok("`Snacks.picker.files()` is available")
  else
    Snacks.health.error("'rg', 'fd' or 'find' is required for `Snacks.picker.files()`")
  end

  if not have_fd or not version_fd then
    Snacks.health.error("'fd' `v8.4` is required for searching with `Snacks.picker.explorer()`")
  else
    Snacks.health.ok("`Snacks.picker.explorer()` is available")
  end

  local ok = pcall(require, "snacks.picker.util.db")
  if ok then
    Snacks.health.ok("`SQLite3` is available")
  else
    Snacks.health.warn("`SQLite3` is not available. Frecency and history will be stored in a file instead.")
  end
end

return M
