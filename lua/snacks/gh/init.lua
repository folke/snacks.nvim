---@class snacks.gh
---@field api snacks.gh.api
---@field item snacks.picker.gh.Item
local M = setmetatable({}, {
  ---@param M snacks.gh
  __index = function(M, k)
    if vim.tbl_contains({ "api" }, k) then
      M[k] = require("snacks.gh." .. k)
    end
    return rawget(M, k)
  end,
})

M.meta = {
  desc = "GitHub CLI integration",
  needs_setup = false,
}

---@alias snacks.gh.Keymap.fn fun(item:snacks.picker.gh.Item, buf:snacks.gh.Buf)
---@class snacks.gh.Keymap: vim.keymap.set.Opts
---@field [1] string lhs
---@field [2] string|snacks.gh.Keymap.fn rhs
---@field mode? string|string[] defaults to `n`

---@class snacks.gh.Config
local defaults = {
  --- Keymaps for GitHub buffers
  ---@type table<string, snacks.gh.Keymap|false>?
  -- stylua: ignore
  keys = {
    select  = { "<cr>", "gh_actions", desc = "Select Action" },
    edit    = { "i"   , "gh_edit"   , desc = "Edit" },
    comment = { "a"   , "gh_comment", desc = "Add Comment" },
    close   = { "c"   , "gh_close"  , desc = "Close" },
    reopen  = { "o"   , "gh_reopen" , desc = "Reopen" },
  },
  ---@type vim.wo|{}
  wo = {
    breakindent = true,
    wrap = true,
    showbreak = "",
    linebreak = true,
    number = false,
    relativenumber = false,
    foldexpr = "v:lua.vim.treesitter.foldexpr()",
    foldmethod = "expr",
    concealcursor = "n",
    conceallevel = 2,
    list = false,
    winhighlight = Snacks.util.winhl({
      Normal = "SnacksGhNormal",
      NormalFloat = "SnacksGhNormalFloat",
      FloatBorder = "SnacksGhBorder",
      FloatTitle = "SnacksGhTitle",
      FloatFooter = "SnacksGhFooter",
    }),
  },
  ---@type vim.bo|{}
  bo = {},
  diff = {
    min = 4, -- minimum number of lines changed to show diff
    wrap = 80, -- wrap diff lines at this length
  },
  scratch = {
    height = 15, -- height of scratch window
  },
  -- stylua: ignore
  icons = {
    logo = " ",
    user= " ",
    checkmark = " ",
    crossmark = " ",
    block = "■",
    file = " ",
    checks = {
      pending = " ",
      success = " ",
      failure = "",
      skipped = " ",
    },
    issue = {
      open      = " ",
      completed = " ",
      other     = " "
    },
    pr = {
      open   = " ",
      closed = " ",
      merged = " ",
      draft  = " ",
      other  = " ",
    },
    review = {
      approved           = " ",
      changes_requested  = " ",
      commented          = " ",
      dismissed          = " ",
      pending            = " ",
    },
    merge_status = {
      clean    = " ",
      dirty    = " ",
      blocked  = " ",
      unstable = " "
    },
    reactions = {
      thumbs_up   = "👍",
      thumbs_down = "👎",
      eyes        = "👀",
      confused    = "😕",
      heart       = "❤️",
      hooray      = "🎉",
      laugh       = "😄",
      rocket      = "🚀",
    },
  },
}

local function diff_linenr(hl)
  local fg = Snacks.util.color({ hl, "SnacksGhNormalFloat", "Normal" })
  local bg = Snacks.util.color({ hl, "SnacksGhNormalFloat", "Normal" }, "bg")
  bg = bg or vim.o.background == "dark" and "#1e1e1e" or "#f5f5f5"
  return {
    fg = fg,
    bg = Snacks.util.blend(fg, bg, 0.1),
  }
end

Snacks.util.set_hl({
  Normal = "NormalFloat",
  NormalFloat = "NormalFloat",
  Border = "FloatBorder",
  Title = "FloatTitle",
  ScratchTitle = "Number",
  ScratchBorder = "Number",
  Footer = "FloatFooter",
  Number = "Number",
  Green = { fg = "#28a745" },
  Purple = { fg = "#6f42c1" },
  Gray = { fg = "#6a737d" },
  Red = { fg = "#d73a49" },
  Branch = "@markup.link",
  IssueOpen = "SnacksGhGreen",
  IssueCompleted = "SnacksGhPurple",
  IssueOther = "SnacksGhGray",
  PrOpen = "SnacksGhGreen",
  PrClosed = "SnacksGhRed",
  PrMerged = "SnacksGhPurple",
  PrDraft = "SnacksGhGray",
  Label = "@property",
  Delim = "@punctuation.delimiter",
  UserBadge = "DiagnosticInfo",
  AuthorBadge = "DiagnosticWarn",
  OwnerBadge = "DiagnosticError",
  BotBadge = { fg = Snacks.util.color({ "NonText", "SignColumn", "FoldColumn" }) },
  ReactionBadge = "Special",
  AssocBadge = {}, -- will be set to inverse of Normal
  StatBadge = "Special",
  PrClean = "DiagnosticInfo",
  PrUnstable = "DiagnosticWarn",
  PrDirty = "DiagnosticError",
  PrBlocked = "DiagnosticError",
  Additions = "SnacksGhGreen",
  Deletions = "SnacksGhRed",
  CheckPending = "DiagnosticWarn",
  CheckSuccess = "SnacksGhGreen",
  CheckFailure = "SnacksGhRed",
  CheckSkipped = "SnacksGhStat",
  ReviewApproved = "SnacksGhGreen",
  ReviewChangesRequested = "DiagnosticError",
  ReviewCommented = {},
  ReviewPending = "DiagnosticWarn",
  CommentAction = "@property",
  DiffHeader = "DiagnosticVirtualTextInfo",
  DiffAdd = "DiffAdd",
  DiffDelete = "DiffDelete",
  DiffContext = "DiffChange",
  DiffAddLineNr = diff_linenr("DiffAdd"),
  DiffDeleteLineNr = diff_linenr("DiffDelete"),
  DiffContextLineNr = diff_linenr("DiffChange"),
  Stat = { fg = Snacks.util.color("SignColumn") },
}, { default = true, prefix = "SnacksGh" })

M._config = nil ---@type snacks.gh.Config?
local did_setup = false

---@param opts? snacks.picker.gh.issue.Config
function M.issue(opts)
  return Snacks.picker.gh_issue(opts)
end

---@param opts? snacks.picker.gh.pr.Config
function M.pr(opts)
  return Snacks.picker.gh_pr(opts)
end

---@private
function M.config()
  M._config = M._config or Snacks.config.get("gh", defaults)
  return M._config
end

---@private
---@param ev? vim.api.keyset.create_autocmd.callback_args
function M.setup(ev)
  if did_setup then
    return
  end
  did_setup = true

  -- vim.treesitter.language.register("markdown", "gh")

  require("snacks.gh.buf").setup()
  if ev then
    vim.schedule(function()
      require("snacks.gh.buf").attach(ev.buf)
    end)
  end
end

return M
