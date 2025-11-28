local M = {}

---@param opts snacks.picker.proc.Config
---@type snacks.picker.finder
function M.panes(opts, ctx)
  local obj = vim
    .system({
      "tmux",
      "list-panes",
      "-aF",
      "#{session_name}:#{window_index}.#{pane_index} #{window_id} #{pane_id} #{window_active} #{pane_active} #{pane_at_top} #{pane_at_bottom} #{pane_at_left} #{pane_at_right} #{pane_current_command}",
    }, { text = true })
    :wait()
  local maxima = {}
  local items = {}
  for line in obj.stdout:gmatch("(.-)\n") do
    local session_name, window_index, pane_index, window_id, pane_id, window_active, pane_active, pane_at_top, pane_at_bottom, pane_at_left, pane_at_right, current_command =
      line:match("^(.+):(%d+)%.(%d+) (@%d+) (%%%d+) ([01]) ([01]) ([01]) ([01]) ([01]) ([01]) (.+)$")
    window_index = tonumber(window_index)
    pane_index = tonumber(pane_index)
    if not maxima[window_id] or pane_index > maxima[window_id] then
      maxima[window_id] = pane_index
    end
    local position
    if pane_at_top == "1" and pane_at_bottom == "0" and pane_at_left == pane_at_right then
      position = "top"
    elseif pane_at_top == "0" and pane_at_bottom == "1" and pane_at_left == pane_at_right then
      position = "bottom"
    elseif pane_at_left == "1" and pane_at_right == "0" and pane_at_top == pane_at_bottom then
      position = "left"
    elseif pane_at_left == "0" and pane_at_right == "1" and pane_at_top == pane_at_bottom then
      position = "right"
    elseif pane_at_top == "1" and pane_at_bottom == "0" and pane_at_left == "1" and pane_at_right == "0" then
      position = "top-left"
    elseif pane_at_top == "1" and pane_at_bottom == "0" and pane_at_left == "0" and pane_at_right == "1" then
      position = "top-right"
    elseif pane_at_top == "0" and pane_at_bottom == "1" and pane_at_left == "1" and pane_at_right == "0" then
      position = "bottom-left"
    elseif pane_at_top == "0" and pane_at_bottom == "1" and pane_at_left == "0" and pane_at_right == "1" then
      position = "bottom-right"
    else
      position = "none"
    end
    items[#items + 1] = {
      type = "pane",
      session_name = session_name,
      window_index = window_index,
      pane_index = pane_index,
      window_id = window_id,
      pane_id = pane_id,
      window_active = window_active == "1",
      pane_active = pane_active == "1",
      position = position,
      current_command = current_command,
      parent = { parent = {} },
    }
  end
  for _, item in ipairs(items) do
    if item.pane_index == maxima[item.window_id] then
      item.last = true
    end
  end
  return items
end

---@param opts snacks.picker.proc.Config
---@type snacks.picker.finder
function M.windows(opts, ctx)
  local obj = vim
    .system({
      "tmux",
      "list-windows",
      "-aF",
      "#{session_name}:#{window_index} #{session_id} #{window_id} #{window_active} #{window_panes} #{window_name}",
    }, { text = true })
    :wait()
  local maxima = {}
  local items = {}
  for line in obj.stdout:gmatch("(.-)\n") do
    local session_name, window_index, session_id, window_id, window_active, window_panes, window_name =
      line:match("^(.+):(%d+)% (%$%d+) (@%d+) ([01]) (%d+) (.+)$")
    window_index = tonumber(window_index)
    if not maxima[session_id] or window_index > maxima[session_id] then
      maxima[session_id] = window_index
    end
    items[#items + 1] = {
      type = "window",
      session_name = session_name,
      window_index = window_index,
      pane_index = -1,
      session_id = session_id,
      window_id = window_id,
      window_active = window_active == "1",
      window_panes = window_panes,
      window_name = window_name,
      parent = {},
    }
  end
  for _, item in ipairs(items) do
    if item.window_index == maxima[item.session_id] then
      item.last = true
    end
  end
  return items
end

---@param opts snacks.picker.proc.Config
---@type snacks.picker.finder
function M.sessions(opts, ctx)
  local obj = vim
    .system(
      { "tmux", "list-sessions", "-F", "#{session_name} #{session_id} #{session_windows} #{session_attached}" },
      { text = true }
    )
    :wait()
  local items = {}
  for line in obj.stdout:gmatch("(.-)\n") do
    local session_name, session_id, session_windows, session_attached = line:match("^(.+) (%$%d+) (%d+) (%d+)$")
    items[#items + 1] = {
      type = "session",
      session_name = session_name,
      session_id = session_id,
      window_index = -1,
      pane_index = -1,
      session_windows = session_windows,
      session_attached = session_attached,
    }
  end
  items[#items].last = true
  return items
end

return M
