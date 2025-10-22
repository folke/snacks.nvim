local M = {}

---@param opts snacks.picker.help.Config
---@type snacks.picker.finder
function M.help(opts, ctx)
  local langs = opts.lang or vim.opt.helplang:get() ---@type string[]
  local rtp = vim.o.runtimepath
  if package.loaded.lazy then
    rtp = rtp .. "," .. table.concat(require("lazy.core.util").get_unloaded_rtp(""), ",")
  end
  local files = vim.fn.globpath(rtp, "doc/*", true, true) ---@type string[]

  if not vim.tbl_contains(langs, "en") then
    langs[#langs + 1] = "en"
  end

  local tag_files = {} ---@type string[]

  for _, file in ipairs(files) do
    local name = vim.fn.fnamemodify(file, ":t")
    local lang = "en"
    if name == "tags" or name:sub(1, 5) == "tags-" then
      lang = name:match("^tags%-(..)$") or lang
      if vim.tbl_contains(langs, lang) then
        tag_files[#tag_files + 1] = file
      end
    end
  end

  ---@async
  ---@param cb async fun(item: snacks.picker.finder.Item)
  return function(cb)
    local done = {} ---@type table<string, boolean>

    for _, file in ipairs(tag_files) do
      local dir = vim.fs.dirname(file)
      for line in io.lines(file) do
        local fields = vim.split(line, string.char(9), { plain = true })
        local tag = fields[1]
        if not line:match("^!_TAG_") and #fields >= 3 and not done[tag] then
          done[tag] = true
          ---@type snacks.picker.finder.Item
          local item = {
            text = tag,
            tag = tag,
            file = dir .. "/" .. fields[2],
            search = "/\\V" .. fields[3]:sub(2),
          }
          if tag:find("^[vbg]?:") or tag:find("^/") then
            item.ft = "vim"
          elseif tag:find("%(%)$") then
            item.ft = "lua"
          elseif tag:find("^'.*'$") then
            item.text_hl = "String"
          elseif tag:find("^E%d+$") then
            item.text_hl = "Error"
          elseif tag:find("^hl%-") then
            item.text_hl = tag:sub(4)
          end
          if item.file then
            cb(item)
          end
        end
      end
    end
  end
end

return M
