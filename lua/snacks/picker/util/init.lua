---@class snacks.picker.util
local M = {}

---@param item snacks.picker.Item
function M.path(item)
  if not (item and item.file) then
    return
  end
  return vim.fs.normalize(item.cwd and item.cwd .. "/" .. item.file or item.file)
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
      buffer:put(tostring(item[key]))
    end
  end
  return buffer:get()
end

---@param text string
---@param width number
---@param align? "left" | "right"
function M.align(text, width, align)
  local tw = vim.api.nvim_strwidth(text)
  if align == "right" then
    return (" "):rep(width - tw) .. text
  end
  return text .. (" "):rep(width - tw)
end

-- Get the word under the cursor or the current visual selection
function M.word()
  if vim.fn.mode():find("v") then
    local saved = vim.fn.getreg("v")
    vim.cmd([[noautocmd sil norm! "vy]])
    local ret = vim.fn.getreg("v")
    vim.fn.setreg("v", saved)
    return ret
  end
  return vim.fn.expand("<cword>")
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
