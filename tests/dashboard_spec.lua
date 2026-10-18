---@module "luassert"

local dashboard = require("snacks.dashboard")
local image = require("snacks.image")

describe("dashboard image", function()
  local original = {}
  local instance
  local placements
  local image_size
  local ready
  local next_id = 100

  before_each(function()
    original.new = image.image.new
    original.env = image.terminal.env
    original.size = image.terminal.size
    original.request = image.terminal.request
    original.set_cursor = image.terminal.set_cursor
    original.terminal = dashboard.sections.terminal
    original.border = vim.o.winborder
    original.columns, original.lines = vim.o.columns, vim.o.lines
    vim.o.columns, vim.o.lines = 160, 50
    vim.o.winborder = "rounded"
    placements = {}
    image_size = { width = 100, height = 200 }
    ready = true
    image.terminal.env = function()
      return { supported = true, placeholders = true }
    end
    image.terminal.size = function()
      return { cell_width = 10, cell_height = 20, scale = 1 }
    end
    image.terminal.request = function() end
    image.image.new = function()
      next_id = next_id + 1
      return {
        id = next_id,
        file = "tests/image/test.png",
        info = { size = image_size, dpi = { width = 96, height = 96 } },
        ready = function()
          return ready
        end,
        failed = function()
          return false
        end,
        place = function(_, placement)
          if not placement.id then
            next_id = next_id + 1
            placement.id = next_id
            placements[#placements + 1] = placement
          end
        end,
        del = function() end,
        _convert = {
          current = function()
            return { name = "test" }
          end,
        },
      }
    end
  end)

  after_each(function()
    if instance and vim.api.nvim_buf_is_valid(instance.buf) then
      vim.api.nvim_buf_delete(instance.buf, { force = true })
    end
    vim.wait(30, function()
      return false
    end)
    image.image.new = original.new
    image.terminal.env = original.env
    image.terminal.size = original.size
    image.terminal.request = original.request
    image.terminal.set_cursor = original.set_cursor
    dashboard.sections.terminal = original.terminal
    vim.o.winborder = original.border
    vim.o.columns, vim.o.lines = original.columns, original.lines
    instance = nil
  end)

  local function open(opts, sections, layout)
    opts = vim.tbl_extend("force", { section = "image", path = "test.png", height = 8, pane = 2 }, opts or {})
    instance = dashboard.open(vim.tbl_extend("force", {
      win = 0,
      buf = vim.api.nvim_create_buf(false, true),
      width = 40,
      row = 0,
      col = 0,
      sections = sections or { { text = "██ Ghost" }, opts },
    }, layout or {}))
    assert.is_true(vim.wait(1000, function()
      return placements[1] and placements[1]._state ~= nil
    end, 10))
    return placements[1], placements[1]:wins()[1]
  end

  it("centers the fitted image in its pane without a default float offset or border", function()
    local placement, win = open()
    assert.are.same({ width = 8, height = 8 }, {
      width = vim.api.nvim_win_get_width(win),
      height = vim.api.nvim_win_get_height(win),
    })
    assert.are.same({ 0, 60 }, vim.api.nvim_win_get_position(win))
    assert.are.same("none", vim.api.nvim_win_get_config(win).border)
    assert.are.same({ 1, 0 }, placement.opts.pos)
  end)

  it("draws the first image row on the first buffer line so the last row fits", function()
    local placement, win = open({ pane = 1 })
    local marks = vim.api.nvim_buf_get_extmarks(placement.buf, image.placement.ns, 0, -1, { details = true })
    assert.is_not_nil(marks[1][4].virt_text)
    local rows = 0
    for _, mark in ipairs(marks) do
      rows = rows + (mark[4].virt_text and 1 or 0) + #(mark[4].virt_lines or {})
    end
    assert.are.equal(vim.api.nvim_win_get_height(win), rows)
  end)

  it("honors width as an aspect-preserving bound and centers the result vertically", function()
    local placement, win = open({ width = 4 })
    assert.are.same({ width = 4, height = 4 }, {
      width = placement._state.loc.width,
      height = placement._state.loc.height,
    })
    assert.are.same({ 2, 62 }, vim.api.nvim_win_get_position(win))
  end)

  it("honors inherited alignment, indentation, and top padding", function()
    local _, win = open(nil, {
      { text = "██ Ghost" },
      {
        pane = 2,
        align = "right",
        indent = 3,
        { section = "image", path = "test.png", height = 8, padding = { 2, 3 } },
      },
    })
    assert.are.same({ 3, 76 }, vim.api.nvim_win_get_position(win))
    assert.are.equal(13, #instance.lines)
  end)

  it("centers an image in pane one", function()
    local _, win = open({ pane = 1 })
    assert.are.same({ 1, 16 }, vim.api.nvim_win_get_position(win))
  end)

  it("clamps oversized dimensions to the pane and preserves a wide image's aspect ratio", function()
    image_size = { width = 800, height = 100 }
    local placement, win = open({ width = 100 })
    assert.are.equal(40, placement._state.loc.width)
    assert.are.equal(3, placement._state.loc.height)
    assert.are.same({ 2, 44 }, vim.api.nvim_win_get_position(win))
  end)

  it("releases the old placement, float, and buffer when the dashboard updates", function()
    local placement, win = open()
    local buf = placement.buf
    instance:update()
    assert.is_true(placement.closed)
    assert.is_false(vim.api.nvim_win_is_valid(win))
    assert.is_false(vim.api.nvim_buf_is_valid(buf))
    assert.is_true(vim.wait(1000, function()
      return placements[2] and placements[2]._state ~= nil
    end, 10))
  end)

  it("removes both cleanup listeners on each update", function()
    open()
    local count = #vim.api.nvim_get_autocmds({ group = instance.augroup })
    for _ = 1, 3 do
      instance:update()
    end
    assert.are.equal(count, #vim.api.nvim_get_autocmds({ group = instance.augroup }))
  end)

  it("fits again when a resize collapses the dashboard into one pane", function()
    open()
    vim.o.columns = 60
    instance:update()
    assert.is_true(vim.wait(1000, function()
      return placements[#placements] and placements[#placements]._state ~= nil
    end, 10))
    local win = placements[#placements]:wins()[1]
    assert.are.equal(1, #instance.panes)
    assert.are.same({ 1, 16 }, vim.api.nvim_win_get_position(win))
  end)

  it("refreshes the image on a terminal resize even when the cell count is unchanged", function()
    local placement = open()
    vim.api.nvim_exec_autocmds("VimResized", {})
    assert.is_true(vim.wait(1000, function()
      return placement.closed and placements[2] and placements[2]._state ~= nil
    end, 10))
  end)

  it("coalesces rapid terminal resizes into one image redraw", function()
    local placement = open()
    for _, columns in ipairs({ 120, 60, 140, 100 }) do
      vim.o.columns = columns
      vim.api.nvim_exec_autocmds("VimResized", {})
    end
    assert.is_false(placement.closed or false)
    assert.is_true(vim.wait(1000, function()
      return placement.closed and placements[2] and placements[2]._state ~= nil
    end, 10))
    assert.are.equal(2, #placements)
    assert.are.equal(100, instance._size.width)
  end)

  it("does not redraw a dashboard that closes while a resize is pending", function()
    open()
    vim.api.nvim_exec_autocmds("VimResized", {})
    vim.api.nvim_buf_delete(instance.buf, { force = true })
    vim.wait(100, function()
      return false
    end)
    assert.are.equal(1, #placements)
  end)

  it("restores the image after a resize in another tab without drawing in that tab", function()
    local placement = open()
    vim.cmd.tabnew()
    local hidden = vim.wait(1000, function()
      return placement.hidden == true
    end, 10)
    vim.o.columns = 100
    vim.api.nvim_exec_autocmds("VimResized", {})
    vim.wait(100, function()
      return false
    end)
    local count = #placements
    vim.cmd.tabclose()
    assert.is_true(hidden)
    assert.are.equal(1, count)
    assert.is_true(vim.wait(1000, function()
      return placement.closed and placements[2] and placements[2]._state and not placements[2].hidden
    end, 10))
  end)

  it("retransmits cached image data when a resize replaces its last placement", function()
    local stored, missing, transmissions = false, false, 0
    image.terminal.request = function(request)
      if request.t == "f" then
        stored = true
        transmissions = transmissions + 1
      elseif request.a == "d" and request.d == "I" then
        stored = false
      elseif request.a == "p" and not stored then
        missing = true
      end
    end
    local cached = setmetatable({
      id = 42,
      file = "tests/image/test.png",
      info = { size = image_size, dpi = { width = 96, height = 96 } },
      placements = {},
      fsize = 0,
      ready = function()
        return true
      end,
      place = function(img, placement)
        if not placement.id then
          placements[#placements + 1] = placement
        end
        image.image.place(img, placement)
      end,
    }, image.image)
    image.image.new = function()
      return cached
    end
    local placement = open()
    assert.are.equal(1, transmissions)
    -- Kitty can discard unreferenced image data, independently of the Lua cache.
    stored = false
    vim.o.columns = 100
    vim.api.nvim_exec_autocmds("VimResized", {})
    assert.is_true(vim.wait(1000, function()
      return placement.closed and placements[2] and placements[2]._state ~= nil
    end, 10))
    assert.are.equal(2, transmissions)
    assert.is_false(missing)
  end)

  it("does not crop an image larger than the window", function()
    image_size = { width = 1000, height = 20000 }
    local placement, win = open({ height = 200 })
    assert.are.equal(vim.api.nvim_win_get_height(win), placement._state.loc.height)
    assert.is_true(placement._state.loc.height <= vim.api.nvim_win_get_height(instance.win))
  end)

  it("uses the same centered float for terminals without Unicode placeholders", function()
    local cursor
    image.terminal.set_cursor = function(pos)
      cursor = pos
    end
    image.terminal.env = function()
      return { supported = true, placeholders = false }
    end
    local _, win = open()
    assert.are.same({ 0, 60 }, vim.api.nvim_win_get_position(win))
    assert.are.same({ 1, 60 }, cursor)
  end)

  it("keeps an explicit zero padding instead of the header's default padding", function()
    open(nil, {
      { section = "header", padding = 0 },
      { section = "image", path = "test.png", height = 8, pane = 2 },
    })
    assert.are.same({ 0, 0 }, instance:padding(instance.items[1]))
    assert.are.equal(6, #instance:format(instance.items[1]))
  end)

  it("passes fallback paths as arguments and preserves the image's aspect ratio", function()
    image.terminal.env = function()
      return { supported = false }
    end
    local fallback
    dashboard.sections.terminal = function(opts)
      fallback = opts
      return function()
        return { text = "fallback" }
      end
    end
    dashboard.sections.image({ path = "~/a b'$(echo test).png", width = 80, height = 12 })({
      opts = { width = 35 },
      _size = { width = 160 },
      win = vim.api.nvim_get_current_win(),
    })
    assert.are.equal(35, fallback.width)
    assert.are.equal("center", fallback.align)
    assert.are.equal(vim.fs.normalize("~/a b'$(echo test).png"), fallback.cmd[#fallback.cmd])
    assert.is_false(vim.tbl_contains(fallback.cmd, "--stretch"))
  end)

  it("loads the image example", function()
    local example = assert(loadfile("docs/examples/dashboard.lua"))().examples.image
    assert.are.equal("image", example.sections[1].section)
  end)

  it("centers the image after an asynchronous conversion finishes", function()
    ready = false
    instance = dashboard.open({
      win = 0,
      buf = vim.api.nvim_create_buf(false, true),
      width = 40,
      row = 0,
      col = 0,
      sections = { { section = "image", path = "test.png", height = 8 } },
    })
    local placement = placements[#placements]
    assert.is_nil(placement._state)
    ready = true
    placement:update()
    assert.is_true(vim.wait(1000, function()
      return placement._state ~= nil
    end, 10))
    assert.are.same({ 0, 16 }, vim.api.nvim_win_get_position(placement:wins()[1]))
  end)

  it("keeps the title's action and shortcut on the title only", function()
    local action = function() end
    open({ title = "Artwork", key = "i", action = action })
    local actions = vim.tbl_filter(function(item)
      return item.action ~= nil
    end, instance.items)
    assert.are.equal(1, #actions)
    assert.are.equal(action, actions[1].action)
    assert.are.equal("i", actions[1].key)
  end)

  it("clamps zero dimensions to one cell", function()
    local placement, win = open({ height = 0, width = 0 })
    assert.are.equal(1, vim.api.nvim_win_get_height(win))
    assert.are.equal(1, vim.api.nvim_win_get_width(win))
    assert.are.equal(1, placement._state.loc.height)
  end)

  it("centers the image pane against a taller text pane without clipping", function()
    local placement, win = open(nil, {
      { text = ("left\n"):rep(11) .. "left" },
      { pane = 2, section = "image", path = "test.png", height = 8 },
    }, { pane_align = "center" })
    assert.are.same({ 2, 60 }, vim.api.nvim_win_get_position(win))
    assert.are.equal(3, instance.items[2]._.row)
    assert.are.equal(12, #instance.lines)
    assert.are.equal(8, placement._state.loc.height)
    assert.are.equal(8, vim.api.nvim_win_get_height(win))
  end)

  it("removes the pane offset when a centered dashboard collapses into one pane", function()
    open(nil, nil, { pane_align = "center" })
    assert.are.equal(4, instance.items[1]._.row)
    vim.o.columns = 60
    instance:update()
    assert.is_true(vim.wait(1000, function()
      return placements[#placements] and placements[#placements]._state ~= nil
    end, 10))
    assert.are.equal(1, #instance.panes)
    assert.are.equal(1, instance.items[1]._.row)
    assert.are.same({ 1, 16 }, vim.api.nvim_win_get_position(placements[#placements]:wins()[1]))
  end)

  if vim.fn.executable("chafa") == 1 then
    for _, align in ipairs({ "top", "center" }) do
      it("positions and cleans up the real fallback with padding and " .. align .. " pane alignment", function()
        image.terminal.env = function()
          return { supported = false }
        end
        instance = dashboard.open({
          win = 0,
          buf = vim.api.nvim_create_buf(false, true),
          width = 40,
          row = 0,
          col = 0,
          pane_align = align,
          sections = {
            { text = ("██ Ghost\n"):rep(16) .. "██ Ghost" },
            {
              pane = 2,
              section = "image",
              path = "tests/image/test.png",
              width = 20,
              height = 8,
              indent = 3,
              padding = { 2, 3 },
            },
          },
        })
        local win = vim.tbl_filter(function(w)
          return w ~= instance.win and vim.api.nvim_win_get_config(w).relative == "win"
        end, vim.api.nvim_list_wins())[1]
        assert.is_not_nil(win)
        local buf = vim.api.nvim_win_get_buf(win)
        assert.is_true(vim.wait(3000, function()
          local job = vim.b[buf].terminal_job_id
          return not job or vim.fn.jobwait({ job }, 0)[1] ~= -1
        end, 10))
        assert.are.same({ align == "center" and 5 or 3, 55 }, vim.api.nvim_win_get_position(win))
        local count = #vim.api.nvim_get_autocmds({ group = instance.augroup })
        instance:update()
        assert.is_false(vim.api.nvim_win_is_valid(win))
        assert.is_false(vim.api.nvim_buf_is_valid(buf))
        assert.are.equal(count, #vim.api.nvim_get_autocmds({ group = instance.augroup }))
      end)
    end
  end
end)

describe("dashboard pane alignment", function()
  local instance
  local original

  before_each(function()
    original = { columns = vim.o.columns, lines = vim.o.lines }
    vim.o.columns, vim.o.lines = 160, 50
  end)

  after_each(function()
    if instance and vim.api.nvim_buf_is_valid(instance.buf) then
      vim.api.nvim_buf_delete(instance.buf, { force = true })
    end
    vim.o.columns, vim.o.lines = original.columns, original.lines
    instance = nil
  end)

  local function open(sections, opts)
    instance = dashboard.open(vim.tbl_extend("force", {
      win = 0,
      buf = vim.api.nvim_create_buf(false, true),
      width = 20,
      row = 2,
      col = 3,
      sections = sections,
    }, opts or {}))
    return instance
  end

  it("keeps panes top aligned by default", function()
    local d = open({ { text = "left" }, { pane = 2, text = "1\n2\n3\n4\n5" } })
    assert.are.equal(3, d.items[1]._.row)
    assert.are.equal(3, d.items[2]._.row)
  end)

  for _, taller in ipairs({ 1, 2 }) do
    it("centers the shorter pane when pane " .. taller .. " is taller", function()
      local shorter = taller == 1 and 2 or 1
      local d = open({
        { pane = shorter, text = "A\nB\nC" },
        { pane = taller, text = "1\n2\n3\n4\n5\n6\n7" },
      }, { pane_align = "center" })
      assert.are.equal(5, d.items[1]._.row)
      assert.are.equal(3, d.items[2]._.row)
      assert.are.equal(9, #d.lines)
    end)
  end

  it("preserves pane columns and highlights when an intermediate pane has a blank row", function()
    local d = open({
      { text = "猫1\n猫2\n猫3\n猫4\n猫5\n猫6\n猫7" },
      { pane = 2, text = "B1\nB2\nB3" },
      { pane = 3, text = { { "C1\nC2\nC3\nC4\nC5", hl = "title" } } },
    }, { pane_align = "center" })
    assert.are.equal(4, d.items[3]._.row)
    local line = d.lines[4]
    local col = assert(line:find("C1", 1, true)) - 1
    assert.are.equal(51, vim.api.nvim_strwidth(line:sub(1, col)))
    local marks = vim.api.nvim_buf_get_extmarks(d.buf, dashboard.ns, { 3, col }, { 3, col }, { details = true })
    assert.are.equal(1, #marks)
    assert.are.equal("SnacksDashboardTitle", marks[1][4].hl_group)
  end)

  it("counts top and bottom padding as part of the pane height", function()
    local d = open({
      { text = "left", padding = { 1, 2 } },
      { pane = 2, text = "1\n2\n3\n4\n5\n6\n7\n8" },
    }, { pane_align = "center" })
    assert.are.equal(5, d.items[1]._.row)
    assert.is_not_nil(d.lines[7]:find("left", 1, true))
    assert.are.equal(10, #d.lines)
  end)

  it("ignores hidden items when measuring panes", function()
    local d = open({
      { text = "left" },
      { text = ("hidden\n"):rep(20), hidden = true },
      { pane = 2, text = "1\n2\n3\n4\n5" },
    }, { pane_align = "center" })
    assert.are.equal(5, d.items[1]._.row)
    assert.are.equal(7, #d.lines)
  end)

  it("supports an empty middle pane", function()
    local d = open({
      { text = "1\n2\n3\n4\n5\n6\n7" },
      { pane = 3, text = "right" },
    }, { pane_align = "center" })
    assert.are.equal(6, d.items[2]._.row)
    assert.are.equal(52, d.lines[6]:find("right", 1, true))
  end)

  it("keeps cursor navigation aligned with the moved actions", function()
    local d = open({
      { text = "left", action = function() end },
      { pane = 2, text = "1\n2\n3\n4\n5", action = function() end },
    }, { pane_align = "center" })
    assert.are.same({ 5, 3 }, vim.api.nvim_win_get_cursor(d.win))
    assert.are.equal(d.items[1], d:find({ 5, 3 }))
    assert.are.equal(d.items[2], d:find({ 3, 27 }))
  end)

  it("keeps single-pane content at its configured row", function()
    local d = open({ { text = "left\nright" } }, { pane_align = "center" })
    assert.are.equal(3, d.items[1]._.row)
    assert.are.equal(4, #d.lines)
  end)
end)
