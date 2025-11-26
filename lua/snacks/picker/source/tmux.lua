local M = {}

---@param opts snacks.picker.proc.Config
---@type snacks.picker.finder
function M.panes(opts, ctx)
  return require("snacks.picker.source.proc").proc(
    ctx:opts({
      cmd = "tmux",
      args = {
        "list-panes",
        "-aF",
        "#{session_name}:#{window_index}.#{pane_index} #{pane_id} #{window_active} #{pane_active} #{pane_at_top} #{pane_at_bottom} #{pane_at_left} #{pane_at_right} #{pane_current_command}",
      },
      transform = function(item)
        local session_name, window_index, pane_index, pane_id, window_active, pane_active, pane_at_top, pane_at_bottom, pane_at_left, pane_at_right, current_command =
          item.text:match("^(.+):(%d+)%.(%d+) (%%%d+) ([01]) ([01]) ([01]) ([01]) ([01]) ([01]) (.+)$")
        item.session_name = session_name
        item.window_index = window_index
        item.pane_index = pane_index
        item.pane_id = pane_id
        item.window_active = window_active == "1"
        item.pane_active = pane_active == "1"
        if pane_at_top == "1" and pane_at_bottom == "0" and pane_at_left == pane_at_right then
          item.position = "top"
        elseif pane_at_top == "0" and pane_at_bottom == "1" and pane_at_left == pane_at_right then
          item.position = "bottom"
        elseif pane_at_left == "1" and pane_at_right == "0" and pane_at_top == pane_at_bottom then
          item.position = "left"
        elseif pane_at_left == "0" and pane_at_right == "1" and pane_at_top == pane_at_bottom then
          item.position = "right"
        elseif pane_at_top == "1" and pane_at_bottom == "0" and pane_at_left == "1" and pane_at_right == "0" then
          item.position = "top-left"
        elseif pane_at_top == "1" and pane_at_bottom == "0" and pane_at_left == "0" and pane_at_right == "1" then
          item.position = "top-right"
        elseif pane_at_top == "0" and pane_at_bottom == "1" and pane_at_left == "1" and pane_at_right == "0" then
          item.position = "bottom-left"
        elseif pane_at_top == "0" and pane_at_bottom == "1" and pane_at_left == "0" and pane_at_right == "1" then
          item.position = "bottom-right"
        else
          item.position = "none"
        end
        item.current_command = current_command
      end,
    }),
    ctx
  )
end

return M
