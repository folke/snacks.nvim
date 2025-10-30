---@class snacks.explorer
---@overload fun(opts?: snacks.picker.explorer.Config): snacks.Picker
local M = setmetatable({}, {
  __call = function(M, ...)
    return M.open(...)
  end,
})

M.meta = {
  desc = "A file explorer (picker in disguise)",
  needs_setup = true,
}

--- These are just the general explorer settings.
--- To configure the explorer picker, see `snacks.picker.explorer.Config`
---@class snacks.explorer.Config
local defaults = {
  replace_netrw = true, -- Replace netrw with the snacks explorer
  trash = true, -- Use the system trash when deleting files
}

M.config = Snacks.config.get("explorer", defaults)

---@private
---@param event? vim.api.keyset.create_autocmd.callback_args
function M.setup(event)
  if M.config.replace_netrw then
    -- Disable netrw
    pcall(vim.api.nvim_del_augroup_by_name, "FileExplorer")

    local group = vim.api.nvim_create_augroup("snacks.explorer", { clear = true })

    local function handle(ev)
      if ev.file ~= "" and vim.fn.isdirectory(ev.file) == 1 then
        local picker = M.open({ cwd = ev.file })
        if picker and vim.v.vim_did_enter == 0 then
          -- clear bufname so we don't try loading this one again
          vim.api.nvim_buf_set_name(ev.buf, "")
          picker:show()
          local ref = picker:ref()
          -- focus on UIEnter, since focusing before doesn't work
          vim.api.nvim_create_autocmd("UIEnter", {
            once = true,
            group = group,
            callback = function()
              local p = ref()
              if p then
                p:focus()
              end
            end,
          })
        else
          -- after vim has entered, we also need to delete the directory buffer
          -- use bufdelete to keep the window layout
          Snacks.bufdelete.delete(ev.buf)
        end
      end
    end

    -- event from snacks loader
    if event then
      handle(event)
    end

    -- Open the explorer when opening a directory
    vim.api.nvim_create_autocmd("BufEnter", {
      group = group,
      callback = handle,
    })
  end
end

--- Shortcut to open the explorer picker
---@param opts? snacks.picker.explorer.Config|{}
function M.open(opts)
  return Snacks.picker.explorer(opts)
end

--- Reveals the given file/buffer or the current buffer in the explorer
---@param opts? {file?:string, buf?:number}
function M.reveal(opts)
  local Actions = require("snacks.explorer.actions")
  local Tree = require("snacks.explorer.tree")
  opts = opts or {}
  local file = svim.fs.normalize(opts.file or vim.api.nvim_buf_get_name(opts.buf or 0))
  local explorer = Snacks.picker.get({ source = "explorer" })[1]

  local function reveal()
    local cwd = explorer:cwd()
    if not Tree:in_cwd(cwd, file) then
      for parent in vim.fs.parents(file) do
        if Tree:in_cwd(parent, cwd) then
          explorer:set_cwd(parent)
          break
        end
      end
    end
    Tree:open(file)
    Actions.update(explorer, { target = file, refresh = true })
  end

  if explorer then
    reveal()
  else
    explorer = M.open({ on_show = reveal })
  end
  return explorer
end

function M.health()
  local cmds = require("snacks.explorer.actions").get_trash_cmds("test")

  if M.config.trash == false then
    Snacks.health.ok("System trash disabled in config")
  else
    local tools = vim.tbl_map(function(cmd)
      return cmd[1]
    end, cmds)
    if Snacks.health.have_tool(tools) then
      Snacks.health.ok("System trash command found")
    else
      Snacks.health.warn("No system trash command found; deleting files will be permanent")
    end
  end
end

return M
