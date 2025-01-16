---@class snacks.picker.util
local M = {}

---@param item snacks.picker.Item
function M.path(item)
  if not (item and item.file) then
    return
  end
  item._path = item._path
    or vim.fs.normalize(item.cwd and item.cwd .. "/" .. item.file or item.file, { _fast = true, expand_env = false })
  return item._path
end

---@param cmd string|string[]
---@param cb fun(output: string[], code: number)
---@param opts? {env?: table<string, string>, cwd?: string}
function M.cmd(cmd, cb, opts)
  local output = {} ---@type string[]
  local id = vim.fn.jobstart(
    cmd,
    vim.tbl_extend("force", opts or {}, {
      on_stdout = function(_, data)
        output[#output + 1] = table.concat(data, "\n")
      end,
      on_exit = function(_, code)
        cb(output, code)
        if code ~= 0 then
          Snacks.notify.error(
            ("Terminal **cmd** `%s` failed with code `%d`:\n- `vim.o.shell = %q`\n\nOutput:\n%s"):format(
              cmd,
              code,
              vim.o.shell,
              vim.trim(table.concat(output, ""))
            )
          )
        end
      end,
    })
  )
  if id <= 0 then
    Snacks.notify.error(("Failed to start job `%s`"):format(cmd))
  end
  return id > 0 and id or nil
end

---@param item table<string, any>
---@param keys string[]
function M.text(item, keys)
  local buffer = require("string.buffer").new()
  for _, key in ipairs(keys) do
    if item[key] then
      if #buffer > 0 then
        buffer:put(" ")
      end
      if key == "pos" or key == "end_pos" then
        buffer:putf("%d:%d", item[key][1], item[key][2])
      else
        buffer:put(tostring(item[key]))
      end
    end
  end
  return buffer:get()
end

---@param text string
---@param width number
---@param opts? {align?: "left" | "right" | "center", truncate?: boolean}
function M.align(text, width, opts)
  opts = opts or {}
  opts.align = opts.align or "left"
  local tw = vim.api.nvim_strwidth(text)
  if tw > width then
    return opts.truncate and (vim.fn.strcharpart(text, 0, width - 1) .. "…") or text
  end
  local left = math.floor((width - tw) / 2)
  local right = width - tw - left
  if opts.align == "left" then
    left, right = 0, width - tw
  elseif opts.align == "right" then
    left, right = width - tw, 0
  end
  return (" "):rep(left) .. text .. (" "):rep(right)
end

---@param text string
---@param width number
function M.truncate(text, width)
  if vim.api.nvim_strwidth(text) > width then
    return vim.fn.strcharpart(text, 0, width - 1) .. "…"
  end
  return text
end

-- Stops visual mode and returns the selected text
function M.visual()
  local modes = { "v", "V", Snacks.util.keycode("<C-v>") }
  local mode = vim.fn.mode():sub(1, 1) ---@type string
  if not vim.tbl_contains(modes, mode) then
    return
  end
  -- stop visual mode
  vim.cmd("normal! " .. mode)

  local pos = vim.api.nvim_buf_get_mark(0, "<")
  local end_pos = vim.api.nvim_buf_get_mark(0, ">")

  -- for some reason, sometimes the column is off by one
  -- see: https://github.com/folke/snacks.nvim/issues/190
  local col_to = math.min(end_pos[2] + 1, #vim.api.nvim_buf_get_lines(0, end_pos[1] - 1, end_pos[1], false)[1])

  local lines = vim.api.nvim_buf_get_text(0, pos[1] - 1, pos[2], end_pos[1] - 1, col_to, {})
  local text = table.concat(lines, "\n")
  ---@class snacks.picker.Visual
  local ret = {
    pos = pos,
    end_pos = end_pos,
    text = text,
  }
  return ret
end

---@param str string
---@param data table<string, string>
function M.tpl(str, data)
  return (str:gsub("(%b{})", function(w)
    return data[w:sub(2, -2)] or w
  end))
end

---@param str string
function M.title(str)
  return table.concat(
    vim.tbl_map(function(s)
      return s:sub(1, 1):upper() .. s:sub(2)
    end, vim.split(str, "_")),
    " "
  )
end

return M
