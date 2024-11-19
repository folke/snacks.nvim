local M = {}

---@param name string
---@param opts? snacks.dashboard.Opts
function M.get(name, opts)
  return vim.tbl_deep_extend("force", {}, M.examples[name], opts or {})
end

---@type table<string, snacks.dashboard.Section>
M.examples = {}

-- Similar to the Emacs Doom dashboard
-- ![image](https://github.com/user-attachments/assets/823f702d-e5d0-449a-afd2-684e1fb97622)
M.examples.doom = {
  sections = {
    { section = "header" },
    { section = "keys", gap = 1, padding = 1 },
    { section = "startup" },
  },
}

-- Similar to the Vim Startify dashboard
-- ![image](https://github.com/user-attachments/assets/561eff8c-ddf0-4de9-8485-e6be18a19c0b)
M.examples.startify = {
  formats = {
    key = function(item)
      return { { "[", hl = "special" }, { item.key, hl = "key" }, { "]", hl = "special" } }
    end,
  },
  sections = {
    { section = "terminal", cmd = "fortune -s | cowsay", hl = "header", padding = 1, indent = 8 },
    { title = "MRU", padding = 1 },
    { section = "recent_files", limit = 8, padding = 1 },
    { title = "MRU ", file = vim.fn.fnamemodify(".", ":~"), padding = 1 },
    { section = "recent_files", cwd = true, limit = 8, padding = 1 },
    { title = "Sessions", padding = 1 },
    { section = "projects", padding = 1 },
    { title = "Bookmarks", padding = 1 },
    { section = "keys" },
  },
}

-- A more advanced example using multiple panes
-- ![image](https://github.com/user-attachments/assets/bbf4d2cd-6fc5-4122-a462-0ca59ba89545)
M.examples.advanced = {
  sections = {
    { section = "header" },
    {
      pane = 2,
      section = "terminal",
      cmd = "colorscript -e square",
      height = 5,
      padding = 1,
    },
    { section = "keys", gap = 1, padding = 1 },
    { pane = 2, icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 1 },
    { pane = 2, icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1 },
    {
      pane = 2,
      icon = " ",
      title = "Git Status",
      section = "terminal",
      enabled = vim.fn.isdirectory(".git") == 1,
      cmd = "hub status --short --branch --renames",
      height = 5,
      padding = 1,
      ttl = 5 * 60,
      indent = 3,
    },
    { section = "startup" },
  },
}

-- A simple example with a header, keys, recent files, and projects
-- ![image](https://github.com/user-attachments/assets/e98997b6-07d3-4162-bc06-2768b78fe353)
M.examples.files = {
  sections = {
    { section = "header" },
    { section = "keys", gap = 1 },
    { icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = { 2, 2 } },
    { icon = " ", title = "Projects", section = "projects", indent = 2, padding = 2 },
    { section = "startup" },
  },
}

-- A more compact version of the `files` example
-- ![image](https://github.com/user-attachments/assets/772e84fe-b220-4841-bbe9-6e28780dc30a)
M.examples.compact_files = {
  sections = {
    { section = "header" },
    { icon = " ", title = "Keymaps", section = "keys", indent = 2, padding = 1 },
    { icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 1 },
    { icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1 },
    { section = "startup" },
  },
}

-- An example using the `chafa` command to display an image
-- ![image](https://github.com/user-attachments/assets/e498ef8f-83ce-4917-a720-8cb31d98ecec)
M.examples.chafa = {
  sections = {
    {
      section = "terminal",
      cmd = "chafa ~/.config/wall.png --format symbols --symbols vhalf --size 60x17 --stretch; sleep .1",
      height = 17,
      padding = 1,
    },
    {
      pane = 2,
      { section = "keys", gap = 1, padding = 1 },
      { section = "startup" },
    },
  },
}

-- Pokemons, because why not?
-- ![image](https://github.com/user-attachments/assets/2fb17ecc-8bc0-48d3-a023-aa8dfc70247e)
M.examples.pokemon = {
  sections = {
    { section = "header" },
    { section = "keys", gap = 1, padding = 1 },
    { section = "startup" },
    {
      section = "terminal",
      cmd = "pokemon-colorscripts -r --no-title; sleep .1",
      random = 10,
      pane = 2,
      indent = 4,
      height = 30,
    },
  },
}

return M
