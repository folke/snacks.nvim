local M = {}

---@class snacks.picker
---@field help fun(opts?: snacks.picker.help.Config): snacks.Picker

---@param opts snacks.picker.help.Config
---@type snacks.picker.finder
function M.help(opts)
  local langs = opts.lang or vim.opt.helplang:get() ---@type string[]
  local rtp = vim.o.runtimepath
  if package.loaded.lazy then
    rtp = rtp .. "," .. table.concat(require("lazy.core.util").get_unloaded_rtp(""), ",")
  end
  local files = vim.fn.globpath(rtp, "doc/*", true, true) ---@type string[]
  ---@async
  ---@param cb async fun(item: snacks.picker.finder.Item)
  return function(cb)
    if not vim.tbl_contains(langs, "en") then
      table.insert(langs, "en")
    end

    local tag_files = {} ---@type table<string, string[]>
    local help_files = {} ---@type table<string, string>

    for _, file in ipairs(files) do
      local name = vim.fn.fnamemodify(file, ":t")
      local lang = "en"
      if name == "tags" or name:sub(1, 5) == "tags-" then
        lang = name:match("^tags%-(..)$") or lang
        if vim.tbl_contains(langs, lang) then
          tag_files[lang] = tag_files[lang] or {}
          table.insert(tag_files[lang], file)
        end
      else
        help_files[name] = file
      end
    end

    local done = {} ---@type table<string, boolean>

    for _, lang in ipairs(langs) do
      for _, file in ipairs(tag_files[lang] or {}) do
        for line in io.lines(file) do
          local fields = vim.split(line, string.char(9), { plain = true })
          if not line:match("^!_TAG_") and #fields == 3 and not done[fields[1]] then
            done[fields[1]] = true
            ---@type snacks.picker.finder.Item
            local item = {
              text = fields[1],
              tag = fields[1],
              file = help_files[fields[2]],
              search = "/\\V" .. fields[3]:sub(2),
            }
            if item.file then
              cb(item)
            end
          end
        end
      end
    end
  end
end

return M
