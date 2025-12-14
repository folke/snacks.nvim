local M = {}

---@param opts snacks.picker.proc.Config
---@type snacks.picker.finder
function M.cliphist(opts, ctx)
  return require("snacks.picker.source.proc").proc(
    ctx:opts({
      cmd = "cliphist",
      args = { "list" },
      ---@param item snacks.picker.finder.Item
      transform = function(item)
        local id, content = item.text:match("^(%d+)%s+(.+)$")
        if id and content and not content:find("^%[%[%s+binary data") then
          item.text = content
          setmetatable(item, {
            __index = function(_, k)
              if k == "data" then
                local data = vim.fn.system({ "cliphist", "decode", id })
                rawset(item, "data", data)
                if vim.v.shell_error ~= 0 then
                  error(data)
                end
                return data
              elseif k == "preview" then
                return {
                  text = item.data,
                  ft = "text",
                }
              end
            end,
          })
        else
          return false
        end
      end,
    }),
    ctx
  )
end

---@param opts snacks.picker.proc.Config
---@type snacks.picker.finder
function M.man(opts, ctx)
  return require("snacks.picker.source.proc").proc(
    ctx:opts({
      cmd = "man",
      args = { "-k", "." },
      ---@param item snacks.picker.finder.Item
      transform = function(item)
        local page, section, desc = item.text:match("^(%S+)%s*%((%S-)%)%s+-%s+(.+)$")
        if page and section and desc then
          item.section = section
          item.desc = desc
          item.page = page
          item.section = section
          item.ref = ("%s(%s)"):format(item.page, item.section or 1)
        else
          return false
        end
      end,
    }),
    ctx
  )
end

return M
