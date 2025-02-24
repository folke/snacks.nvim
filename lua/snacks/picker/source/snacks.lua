local M = {}

---@param opts snacks.picker.notifications.Config
function M.notifier(opts)
  local notifs = Snacks.notifier.get_history({ filter = opts.filter, reverse = true })
  local items = {} ---@type snacks.picker.finder.Item[]

  for _, notif in ipairs(notifs) do
    items[#items + 1] = {
      text = Snacks.picker.util.text(notif, { "level", "title", "msg" }),
      item = notif,
      severity = notif.level,
      preview = {
        text = notif.msg,
        ft = "markdown",
      },
    }
  end

  return items
end

return M
