local Snacks = require("snacks")

local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local conf = require("telescope.config").values
local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local entry_display = require("telescope.pickers.entry_display")
local previewers = require("telescope.previewers")

local widths = {
  time = nil,
  title = nil,
  icon = nil,
  level = nil,
  message = nil,
}

local displayer = entry_display.create({
  separator = "",
  items = {
    { width = widths.time },
    { width = 1 },
    { width = widths.icon },
    { width = 1 },
    { width = widths.level },
    { width = 1 },
    { width = widths.title },
    { width = 1 },
    { remaining = true },
  },
})

local telescope_notifications = function(opts)
  local notifs = Snacks.notifier.get_history()
  local reversed = {}
  for i, notif in ipairs(notifs) do
    local preview = notif._preview

    if not preview then
      notif._preview = {}
      local prefix = Snacks.notifier.get_prefix(notif)
      notif._preview.prefix = prefix
      notif._preview.msg_title = vim.split(notif.msg, "\n")[1]
    end

    reversed[#notifs - i + 1] = notif
  end
  pickers
    .new(opts, {
      results_title = "Notifications",
      prompt_title = "Filter Notifications",
      finder = finders.new_table({
        results = reversed,
        entry_maker = function(notif)
          return {
            value = notif,
            display = function(entry)
              local t = { unpack(entry.value._preview.prefix) }
              table.insert(t, { entry.value._preview.msg_title, "SnacksNotifierTitle" })
              return displayer(t)
            end,
            ordinal = notif.msg,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection == nil then
            return
          end

          local notif = selection.value
          Snacks.notifier.show_preview(notif)
        end)
        return true
      end,
      previewer = previewers.new_buffer_previewer({
        title = "Message",
        define_preview = function(self, entry, status)
          local notif = entry.value
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, vim.split(notif.msg, "\n"))
          vim.api.nvim_set_option_value("wrap", true, { win = status.preview_win })
          -- vim.api.nvim_set_option_value("filetype", "markdown", { buf = self.state.bufnr })
        end,
      }),
    })
    :find()
end

return require("telescope").register_extension({
  exports = {
    notifier = telescope_notifications,
  },
})
