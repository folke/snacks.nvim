local M = {}

M.meta = {
  desc = "Doc-gen for Snacks",
  hide = true,
}

local query = vim.treesitter.query.parse(
  "lua",
  [[
    ;; top-level locals
    ((variable_declaration (
      assignment_statement 
        (variable_list name: (identifier) @local_name)
        (expression_list value: (_) @local_value)
        (#match? @local_value "(setmetatable|\\{)")
      )) @local
      (#any-of? @local_name "M" "defaults" "config")
      (#has-parent? @local chunk))

    ;; top-level functions/methods
    (function_declaration 
      name: (_) @fun_name (#match? @fun_name "^M")
      parameters: (_) @fun_params
    ) @fun

    ;; styles
    (function_call
      name: (dot_index_expression) @_sf (#eq? @_sf "Snacks.config.style")
      arguments: (arguments
        (string content: (string_content) @style_name)
        (table_constructor) @style_config)
    ) @style

    ;; examples
    (assignment_statement
      (variable_list
        name: (dot_index_expression
          field: (identifier) @example_name) 
          @_en (#lua-match? @_en "^M%.examples%.%w+"))
      (expression_list
        value: (table_constructor) @example_config)
    ) @example

    ;; props
    (assignment_statement
      (variable_list
        name: (dot_index_expression
          field: (identifier) @prop_name) 
          @_pn (#lua-match? @_pn "^M%."))
      (expression_list
        value: (_) @prop_value)
    ) @prop
  ]]
)

---@class snacks.docs.Capture
---@field name string
---@field line number
---@field node TSNode
---@field text string
---@field comment string
---@field fields table<string, string>

---@class snacks.docs.Parse
---@field captures snacks.docs.Capture[]
---@field comments string[]

---@class snacks.docs.Method
---@field mod string
---@field name string
---@field args string
---@field comment? string
---@field types? string
---@field type "method"|"function"}[]

---@class snacks.docs.Info
---@field config? string
---@field mod? string
---@field modname? string
---@field methods snacks.docs.Method[]
---@field types string[]
---@field setup? string
---@field examples table<string, string>
---@field styles {name:string, opts:string, comment?:string}[]
---@field props table<string, string>

---@param lines string[]
function M.parse(lines)
  local source = table.concat(lines, "\n")
  local parser = vim.treesitter.get_string_parser(source, "lua")
  parser:parse()

  local comments = {} ---@type string[]
  for l, line in ipairs(lines) do
    if line:find("^%-%-") then
      comments[l] = line
      if comments[l - 1] then
        comments[l] = comments[l - 1] .. "\n" .. comments[l]
        comments[l - 1] = nil
      end
    end
  end

  ---@type snacks.docs.Parse
  local ret = { captures = {}, comments = {} }

  local used_comments = {} ---@type table<number, boolean>
  for id, node in query:iter_captures(parser:trees()[1]:root(), source) do
    local name = query.captures[id]
    if not name:find("_") then
      -- add fields
      local fields = {}
      for id2, node2 in query:iter_captures(node, source) do
        local c = query.captures[id2]
        if c:find(name .. "_") then
          fields[c:gsub("^.*_", "")] = vim.treesitter.get_node_text(node2, source)
        end
      end

      -- add comments
      local comment = "" ---@type string
      if comments[node:start()] then
        comment = comments[node:start()]
        used_comments[node:start()] = true
      end

      if not comment:find("@deprecated") then
        table.insert(ret.captures, {
          text = vim.treesitter.get_node_text(node, source),
          name = name,
          comment = comment,
          line = node:start() + 1,
          node = node,
          fields = fields,
        })
      end
    end
  end
  for l in pairs(used_comments) do
    comments[l] = nil
  end

  -- remove comments that are followed by code
  for l in pairs(comments) do
    if lines[l + 1] and lines[l + 1]:find("^.+$") then
      comments[l] = nil
    end
  end
  for l in ipairs(lines) do
    if comments[l] then
      table.insert(ret.comments, comments[l])
    end
  end

  return ret
end

---@param lines string[]
---@param opts {prefix: string, name:string}
function M.extract(lines, opts)
  local fqn = opts.prefix .. "." .. opts.name
  local parse = M.parse(lines)
  ---@type snacks.docs.Info
  local ret = {
    methods = {},
    types = vim.tbl_filter(function(c)
      return not c:find("@private")
    end, parse.comments),
    styles = {},
    examples = {},
    props = {},
  }

  for _, c in ipairs(parse.captures) do
    if
      c.comment:find("@private")
      or c.comment:find("@protected")
      or c.comment:find("@package")
      or c.comment:find("@hide")
    then
      -- skip private
    elseif c.name == "local" then
      if vim.tbl_contains({ "defaults", "config" }, c.fields.name) then
        ret.config = vim.trim(c.comment .. "\n" .. c.fields.value)
      elseif c.fields.name == "M" then
        ret.mod = c.comment
      end
    elseif c.name == "prop" then
      local name = c.fields.name:sub(1)
      local value = c.fields.value
      ret.props[name] = c.comment == "" and value or c.comment .. "\n" .. value
    elseif c.name == "fun" then
      local name = c.fields.name:sub(2)
      local args = (c.fields.params or ""):sub(2, -2)
      local type = name:sub(1, 1)
      name = name:sub(2)
      if not name:find("^_") then
        table.insert(ret.methods, {
          mod = type == ":" and opts.name or fqn,
          name = name,
          args = args,
          comment = c.comment,
          type = type,
        })
      end
    elseif c.name == "style" then
      table.insert(ret.styles, { name = c.fields.name, opts = c.fields.config, comment = c.comment })
    elseif c.name == "example" then
      ret.examples[c.fields.name] = c.comment .. "\n" .. c.fields.config
    end
  end

  if ret.mod then
    local mod_lines = vim.split(ret.mod, "\n")
    mod_lines = vim.tbl_filter(function(line)
      local overload = line:match("^%-%-%-%s*@overload (.*)(%s*)$") --[[@as string?]]
      if overload then
        table.insert(ret.methods, {
          mod = fqn,
          name = "",
          args = "",
          type = "",
          comment = "---@type " .. overload,
        })
        return false
      elseif line:find("^%s*$") then
        return false
      end
      return true
    end, mod_lines)
    ret.mod = table.concat(mod_lines, "\n")
  end

  return ret
end

---@param tag string
---@param readme string
---@param content string
function M.replace(tag, readme, content)
  content = vim.trim(content)
  local pattern = "(<%!%-%- " .. tag .. ":start %-%->).*(<%!%-%- " .. tag .. ":end %-%->)"
  if not readme:find(pattern) then
    error("tag " .. tag .. " not found")
  end
  return readme:gsub(pattern, "%1\n\n" .. content .. "\n\n%2")
end

---@param str string
---@param opts? {extract_comment: boolean} -- default true
function M.md(str, opts)
  str = str or ""
  str = str:gsub("\r", "")
  opts = opts or {}
  if opts.extract_comment == nil then
    opts.extract_comment = true
  end
  str = str:gsub("\n%s*%-%-%s*stylua: ignore\n", "\n")
  str = str:gsub("\n%s*debug = false,\n", "\n")
  str = str:gsub("\n%s*debug = true,\n", "\n")
  local comments = {} ---@type string[]
  local lines = vim.split(str, "\n", { plain = true })

  if opts.extract_comment then
    while lines[1] and lines[1]:find("^%-%-") and not lines[1]:find("^%-%-%-%s*@") do
      local line = table.remove(lines, 1):gsub("^[%-]*%s*", "")
      table.insert(comments, line)
    end
  end

  local ret = {} ---@type string[]
  if #comments > 0 then
    table.insert(ret, vim.trim(table.concat(comments, "\n")))
    table.insert(ret, "")
  end
  if #lines > 0 then
    table.insert(ret, "```lua")
    table.insert(ret, vim.trim(table.concat(lines, "\n")))
    table.insert(ret, "```")
  end

  return vim.trim(table.concat(ret, "\n")) .. "\n"
end

function M.examples(name)
  local fname = ("docs/examples/%s.lua"):format(name)
  if not vim.uv.fs_stat(fname) then
    return {}
  end
  local lines = vim.fn.readfile(fname)
  local info = M.extract(lines, { prefix = "Snacks.examples", name = name })
  return info.examples
end

---@param name string
---@param info snacks.docs.Info
---@param opts? {setup?:boolean, config?:boolean, styles?:boolean, types?:boolean, prefix?:string, examples?:boolean}
function M.render(name, info, opts)
  opts = opts or {}
  local lines = {} ---@type string[]
  local function add(line)
    table.insert(lines, line)
  end

  local prefix = ("Snacks.%s"):format(name)
  if name == "init" then
    prefix = "Snacks"
  end
  if info.modname then
    prefix = "local M"
  end

  if name ~= "init" and (info.config or info.setup) and opts.setup ~= false then
    add("## 📦 Setup\n")
    add(([[
```lua
-- lazy.nvim
{
  "folke/snacks.nvim",
  ---@type snacks.Config
  opts = {
    %s = {
      -- your %s configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    }
  }
}
```
]]):format(info.setup or name, name))
  end

  if info.config and opts.config ~= false then
    add("## ⚙️ Config\n")
    add(M.md(info.config))
  end

  if opts.examples ~= false then
    local examples = M.examples(name)
    local names = vim.tbl_keys(examples)
    table.sort(names)
    if not vim.tbl_isempty(examples) then
      add("## 🚀 Examples\n")
      for _, n in ipairs(names) do
        local example = examples[n]
        add(("### `%s`\n"):format(n))
        add(M.md(example))
      end
    end
  end

  if #info.styles > 0 and opts.styles ~= false then
    table.sort(info.styles, function(a, b)
      return a.name < b.name
    end)
    add("## 🎨 Styles\n")

    if name == "styles" then
      add([[These are the default styles that Snacks provides.
You can customize them by adding your own styles to `opts.styles`.

]])
    else
      add([[Check the [styles](https://github.com/folke/snacks.nvim/blob/main/docs/styles.md)
docs for more information on how to customize these styles
]])
    end

    for _, style in pairs(info.styles) do
      add(("### `%s`\n"):format(style.name))
      if style.comment and style.comment ~= "" then
        add(M.md(style.comment))
      end
      add(M.md(style.opts))
    end
  end

  if #info.types > 0 and opts.types ~= false then
    add("## 📚 Types\n")
    for _, t in ipairs(info.types) do
      add(M.md(t))
    end
  end

  local mod_lines = info.mod and not info.mod:find("^%s*$") and vim.split(info.mod, "\n") or {}
  local hide = #mod_lines == 0 or (#mod_lines == 1 and mod_lines[1]:find("@class"))

  if not hide or #info.methods > 0 then
    local title = info.modname and ("`%s`"):format(info.modname) or "Module"
    add(("## 📦 %s\n"):format(title))
  end

  if info.mod and not hide then
    table.insert(mod_lines, prefix .. " = {}")
    add(M.md(table.concat(mod_lines, "\n")))
  end

  table.sort(info.methods, function(a, b)
    if a.mod ~= b.mod then
      return a.mod < b.mod
    end
    if a.type == b.type then
      return a.name < b.name
    end
    return a.type < b.type
  end)

  local last ---@type string?
  for _, method in ipairs(info.methods) do
    local title = ("### `%s%s%s()`\n"):format(method.mod, method.type, method.name)
    if title ~= last then
      last = title
      add(title)
    end
    local code = ("%s\n%s%s%s(%s)"):format(method.comment or "", method.mod, method.type, method.name, method.args)
    add(M.md(code))
  end

  lines = vim.split(vim.trim(table.concat(lines, "\n")), "\n")
  return lines
end

function M.write(name, lines)
  local path = ("docs/%s.md"):format(name)
  local ok, text = pcall(vim.fn.readfile, path)

  local docgen = "<!-- docgen -->"
  local top = {} ---@type string[]

  if not ok then
    table.insert(top, "# 🍿 " .. name)
    table.insert(top, "")
  else
    for _, line in ipairs(text) do
      if line == docgen then
        break
      end
      table.insert(top, line)
    end
  end
  table.insert(top, docgen)
  table.insert(top, "")
  vim.list_extend(top, lines)

  vim.fn.writefile(vim.split(table.concat(top, "\n"), "\n"), path)
end

---@param ret string[]
function M.picker(ret)
  local lines = vim.fn.readfile("lua/snacks/picker/config/sources.lua")
  local info = M.extract(lines, { prefix = "Snacks.picker", name = "sources" })
  local sources = vim.tbl_keys(info.props)
  table.sort(sources)
  local source_types = {} ---@type table<string, string>
  table.insert(ret, "## 🔍 Sources\n")
  for _, source in ipairs(sources) do
    local opts = info.props[source]
    local opts_lines = vim.split(opts, "\n")
    for _, l in ipairs(opts_lines) do
      local t = l:match("^---@type (.*)$")
      t = t or l:match("^---@class (.*)$")
      if t then
        t = vim.trim(t:gsub(":.*", ""))
        source_types[source] = t
        break
      end
    end
    table.insert(ret, ("### `%s`"):format(source))
    table.insert(ret, "")
    table.insert(ret, ("```vim\n:lua Snacks.picker.%s(opts?)\n```\n"):format(source))
    table.insert(ret, M.md(opts))
  end
  M.picker_types(source_types)
  lines = vim.fn.readfile("lua/snacks/picker/config/layouts.lua")
  info = M.extract(lines, { prefix = "Snacks.picker", name = "layouts" })
  sources = vim.tbl_keys(info.props)
  table.sort(sources)
  table.insert(ret, "## 🖼️ Layouts\n")
  for _, source in ipairs(sources) do
    local opts = info.props[source]
    table.insert(ret, ("### `%s`"):format(source))
    table.insert(ret, "")
    table.insert(ret, M.md(opts))
  end
end

function M._build()
  local plugins = Snacks.meta.get()
  ---@class snacks.docs.Types
  local types = {
    fields = {}, ---@type string[]
    config = {}, ---@type string[]
  }

  ---@type snacks.docs.Info
  local styles = {
    methods = {},
    types = {},
    examples = {},
    styles = {},
    setup = "---@type table<string, snacks.win.Config>\n    styles",
    props = {},
  }

  for _, plugin in pairs(plugins) do
    if plugin.meta.docs then
      local name = plugin.name
      print("[gen] " .. name .. ".md")
      local lines = vim.fn.readfile(plugin.file)
      local info = M.extract(lines, { prefix = "Snacks", name = name })

      local children = {} ---@type snacks.docs.Info[]
      for c, child in pairs(plugin.meta.merge or {}) do
        local child_name = type(c) == "number" and child or c --[[@as string]]
        local child_file = ("%s/%s/%s"):format(Snacks.meta.root, name, child:gsub("%.", "/"))
        for _, f in ipairs({ ".lua", "/init.lua" }) do
          if vim.uv.fs_stat(child_file .. f) then
            child_file = child_file .. f
            break
          end
        end
        assert(vim.uv.fs_stat(child_file), ("file not found: %s"):format(child_file))
        local child_lines = vim.fn.readfile(child_file)
        local child_info = M.extract(child_lines, { prefix = "Snacks." .. name, name = child_name })
        child_info.modname = "snacks." .. name .. "." .. child
        if child_info.config then
          assert(not info.config, "config already exists")
          info.config = child_info.config
        end
        vim.list_extend(info.types, child_info.types)
        table.insert(children, child_info)
      end

      vim.list_extend(styles.styles, info.styles)
      info.config = name ~= "init" and info.config or nil
      plugin.meta.config = info.config ~= nil

      local rendered = {} ---@type string[]
      vim.list_extend(rendered, M.render(name, info))
      if name == "picker" then
        M.picker(rendered)
      end

      for _, child in ipairs(children) do
        table.insert(rendered, "")
        vim.list_extend(
          rendered,
          M.render(name, child, {
            setup = false,
            config = false,
            styles = false,
            types = false,
            examples = false,
          })
        )
      end

      M.write(name, rendered)

      if plugin.meta.types then
        table.insert(types.fields, ("---@field %s snacks.%s"):format(plugin.name, plugin.name))
      end
      if plugin.meta.config then
        table.insert(types.config, ("---@field %s? snacks.%s.Config"):format(plugin.name, plugin.name))
      end
    end
  end
  M.write("styles", M.render("styles", styles))

  M.readme(plugins, types)
  M.types(types)

  vim.cmd.checktime()
end

---@param types snacks.docs.Types
function M.types(types)
  local lines = {} ---@type string[]
  lines[#lines + 1] = "---@meta _"
  lines[#lines + 1] = ""
  lines[#lines + 1] = "---@class snacks.plugins"
  vim.list_extend(lines, types.fields)
  lines[#lines + 1] = ""
  lines[#lines + 1] = "---@class snacks.plugins.Config"
  vim.list_extend(
    lines,
    vim.tbl_map(function(field)
      -- make all fields optional
      return field .. "|{}"
    end, types.config)
  )

  vim.fn.writefile(lines, "lua/snacks/meta/types.lua")
end

---@param types table<string,string>
function M.picker_types(types)
  local opts = Snacks.picker.config.get() --[[@as table<string,unknown>]]
  local sources = vim.tbl_keys(opts.sources) ---@type string[]
  table.sort(sources)
  local lines = {} ---@type string[]
  lines[#lines + 1] = "---@meta _"
  lines[#lines + 1] = ""
  lines[#lines + 1] = "---@class snacks.picker"
  for _, source in ipairs(sources) do
    if source ~= "select" then
      local t = types[source] or "snacks.picker.Config"
      t = t:gsub("|.*", "") .. "|{}"
      if source == "resume" then
        lines[#lines + 1] = ("---@field %s fun(): snacks.Picker"):format(source)
      else
        lines[#lines + 1] = ("---@field %s fun(opts?: %s): snacks.Picker"):format(source, t)
      end
    end
  end
  vim.fn.writefile(lines, "lua/snacks/picker/types.lua")
end

---@param plugins snacks.meta.Plugin[]
---@param types snacks.docs.Types
function M.readme(plugins, types)
  local path = "lua/snacks/init.lua"
  local lines = vim.fn.readfile(path) --[[ @as string[] ]]
  local info = M.extract(lines, { prefix = "Snacks", name = "init" })
  local readme = table.concat(vim.fn.readfile("README.md"), "\n")
  local example = table.concat(vim.fn.readfile("docs/examples/init.lua"), "\n")
  local e = M.examples("picker").general or ""
  local l = vim.split(e, "\n")
  table.remove(l)
  table.remove(l)
  local start = false
  l = vim.tbl_filter(function(line)
    if line:find("^%s*keys =") then
      start = true
      return false
    end
    return start
  end, l)
  l[1] = vim.trim(l[1])
  e = table.concat(l, "\n")
  example = example:gsub("%-%- EXTRA_KEYS", e)

  -- config type
  lines = {}
  lines[1] = "---@class snacks.Config"
  vim.list_extend(lines, types.config)
  local config_lines = vim.split(info.config or "", "\n")
  table.remove(config_lines, 1)
  vim.list_extend(lines, config_lines)
  info.config = table.concat(lines, "\n")

  -- snacks type
  lines = {}
  lines[#lines + 1] = "---@class Snacks"
  vim.list_extend(lines, types.fields)
  info.mod = table.concat(lines, "\n")

  -- toc
  lines = {}
  lines[#lines + 1] = "| Snack | Description | Setup |"
  lines[#lines + 1] = "| ----- | ----------- | :---: |"
  for _, plugin in ipairs(plugins) do
    if plugin.meta.readme then
      lines[#lines + 1] = ("| %s | %s | %s |"):format(
        ("[%s](https://github.com/folke/snacks.nvim/blob/main/docs/%s.md)"):format(plugin.name, plugin.name),
        plugin.meta.desc,
        plugin.meta.needs_setup and "‼️" or ""
      )
    end
  end

  M.write("init", M.render("init", info))
  example = example:gsub(".*\nreturn {", "{", 1)
  readme = M.replace("config", readme, M.md(info.config))
  readme = M.replace("example", readme, M.md(example))
  readme = M.replace("toc", readme, table.concat(lines, "\n"))
  vim.fn.writefile(vim.split(readme, "\n"), "README.md")
end

function M.fix_titles()
  for file, t in vim.fs.dir("doc", { depth = 1 }) do
    if t == "file" and file:find("%.txt$") then
      local lines = vim.fn.readfile("doc/" .. file) --[[@as string[] ]]
      lines[1] = lines[1]:gsub("%.txt", ""):gsub("%.nvim", "")
      for i, line in ipairs(lines) do
        -- Example: SNACKS.GIT.BLAME_LINE()            *snacks-git-module-snacks.git.blame_line()*
        local func = line:gsub("^SNACKS.*module%-snacks(.+%(%))%*$", "Snacks%1")
        if func ~= line then
          local left = ("`%s`"):format(func)
          local right = ("*%s*"):format(func)
          line = left .. string.rep(" ", #line - #left - #right) .. right
          lines[i] = line
        end
      end
      vim.fn.writefile(lines, "doc/" .. file)
    end
  end
  vim.cmd.helptags("doc")
end

function M.build()
  local ok, err = pcall(M._build)
  if not ok then
    vim.api.nvim_err_writeln(err)
    os.exit(1)
  end
end

return M
