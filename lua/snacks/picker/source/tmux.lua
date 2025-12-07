local M = {}

---@param opts snacks.picker.proc.Config
function M.panes(opts, ctx)
  local obj = vim
    .system({
      "tmux",
      "list-panes",
      "-aF",
      "#{session_name}:#{window_index}.#{pane_index} #{session_id} #{window_id} #{pane_id} #{window_active} #{pane_active} #{pane_at_top} #{pane_at_bottom} #{pane_at_left} #{pane_at_right} #{pane_current_command}",
    }, { text = true })
    :wait()
  local items = {}
  for line in obj.stdout:gmatch("(.-)\n") do
    local session_name, window_index, pane_index, session_id, window_id, pane_id, window_active, pane_active, pane_at_top, pane_at_bottom, pane_at_left, pane_at_right, current_command =
      line:match("^(.+):(%d+)%.(%d+) (%$%d+) (@%d+) (%%%d+) ([01]) ([01]) ([01]) ([01]) ([01]) ([01]) (.+)$")
    window_index = tonumber(window_index)
    pane_index = tonumber(pane_index)
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
      session_id = session_id,
      window_id = window_id,
      pane_id = pane_id,
      window_active = window_active == "1",
      pane_active = pane_active == "1",
      position = position,
      current_command = current_command,
      text = ("%s:%s.%s %s %s %s %s %s"):format(
        session_name,
        window_index,
        pane_index,
        session_id,
        window_id,
        pane_id,
        current_command,
        pane_active and "active" or ""
      ),
    }
  end
  return items
end

---@param opts snacks.picker.proc.Config
function M.windows(opts, ctx)
  local obj = vim
    .system({
      "tmux",
      "list-windows",
      "-aF",
      "#{session_name}:#{window_index} #{session_id} #{window_id} #{window_active} #{window_panes} #{window_name}",
    }, { text = true })
    :wait()
  local items = {}
  for line in obj.stdout:gmatch("(.-)\n") do
    local session_name, window_index, session_id, window_id, window_active, window_panes, window_name =
      line:match("^(.+):(%d+)% (%$%d+) (@%d+) ([01]) (%d+) (.+)$")
    window_index = tonumber(window_index)
    window_panes = tonumber(window_panes)
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
      text = ("%s:%s. %s %s %s %s"):format(
        session_name,
        window_index,
        session_id,
        window_id,
        window_name,
        window_active and "active" or ""
      ),
    }
  end
  return items
end
    }
  end
  return items
end

---@param opts snacks.picker.proc.Config
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
    session_windows = tonumber(session_windows)
    session_attached = tonumber(session_attached)
    items[#items + 1] = {
      type = "session",
      session_name = session_name,
      session_id = session_id,
      window_index = -1,
      pane_index = -1,
      session_windows = session_windows,
      session_attached = session_attached,
      text = ("%s: %s %s"):format(session_name, session_id, session_attached > 0 and "client" or ""),
    }
  end
  return items
end

---@param opts snacks.picker.proc.Config
function M.tree(opts, ctx)
  local panes = M.panes(opts, ctx)
  local windows = M.windows(opts, ctx)
  local sessions = M.sessions(opts, ctx)

  local session_map = {}
  local window_map = {}
  local session_maxima = {}
  local window_maxima = {}

  for _, session in ipairs(sessions) do
    session.tree = true
    session_map[session.session_id] = session
  end
  for _, window in ipairs(windows) do
    window.tree = true
    window_map[window.window_id] = window
    if not session_maxima[window.session_id] or window.window_index > session_maxima[window.session_id] then
      session_maxima[window.session_id] = window.window_index
    end
  end
  for _, pane in ipairs(panes) do
    pane.tree = true
    if not window_maxima[pane.window_id] or pane.pane_index > window_maxima[pane.window_id] then
      window_maxima[pane.window_id] = pane.pane_index
    end
  end

  sessions[#sessions].last = true
  for _, window in ipairs(windows) do
    window.parent = session_map[window.session_id]
    if window.window_index == session_maxima[window.session_id] then
      window.last = true
    end
  end
  for _, pane in ipairs(panes) do
    pane.parent = window_map[pane.window_id]
    if pane.pane_index == window_maxima[pane.window_id] then
      pane.last = true
    end
  end

  local items = {}
  vim.list_extend(items, sessions)
  vim.list_extend(items, windows)
  vim.list_extend(items, panes)
  return items
end

return M
