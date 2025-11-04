describe("picker.diff", function()
  local diff = require("snacks.picker.source.diff")

  describe("parse", function()
    it("parses git diff format", function()
      local lines = {
        "diff --git a/file.txt b/file.txt",
        "index abc123..def456 100644",
        "--- a/file.txt",
        "+++ b/file.txt",
        "@@ -1,3 +1,3 @@ context",
        " unchanged",
        "-old line",
        "+new line",
      }

      local blocks = diff.parse(lines)
      assert.equals(1, #blocks)
      assert.equals("file.txt", blocks[1].file)
      assert.equals(4, #blocks[1].header)
      assert.equals(1, #blocks[1].hunks)
      assert.equals(1, blocks[1].hunks[1].line)
      assert.equals(4, #blocks[1].hunks[1].diff)
    end)

    it("doesn't parse a filename from deleted lua comment", function()
      local lines = {
        "diff --git a/lua/todo-comments/config.lua b/lua/todo-comments/config.lua",
        "index 0e2d34e..a8e1077 100644",
        "--- a/lua/todo-comments/config.lua",
        "+++ b/lua/todo-comments/config.lua",
        "@@ -11,7 +11,6 @@ M.loaded = false",
        ' M.ns = vim.api.nvim_create_namespace("todo-comments")',
        "",
        " --- @class TodoOptions",
        "--- TODO: add support for markdown todos",
        " local defaults = {",
        "   signs = true, -- show icons in the signs column",
        "   sign_priority = 8, -- sign priority",
        "      }",
        "    end)",
        "",
      }
      local blocks = diff.parse(lines)
      assert.equals(1, #blocks)
      assert.equals("lua/todo-comments/config.lua", blocks[1].file)
    end)

    it("parses plain diff format (no git header)", function()
      local lines = {
        "--- file1.txt\t2024-01-01 12:00:00",
        "+++ file2.txt\t2024-01-02 12:00:00",
        "@@ -1,3 +1,3 @@",
        " unchanged",
        "-old line",
        "+new line",
      }

      local blocks = diff.parse(lines)
      assert.equals(1, #blocks)
      assert.equals("file2.txt", blocks[1].file)
      assert.equals(2, #blocks[1].header)
      assert.equals(1, #blocks[1].hunks)
      assert.equals(1, blocks[1].hunks[1].line)
    end)

    it("parses plain diff format (recursive)", function()
      local lines = {
        "diff -Naur old/file1.txt new/file1.txt",
        "--- old/file1.txt	2025-01-01 13:00:00.000000000 +0100",
        "+++ new/file1.txt	1970-01-01 01:00:00.000000000 +0100",
        "@@ -1,3 +0,0 @@",
        "-context1",
        "-old content",
        "-context3",
        "diff -Naur old/file2.txt new/file2.txt",
        "--- old/file2.txt	1970-01-01 01:00:00.000000000 +0100",
        "+++ new/file2.txt	2025-01-01 13:00:00.000000000 +0100",
        "@@ -0,0 +1,3 @@",
        "+context1",
        "+new line",
        "+context3",
      }

      local blocks = diff.parse(lines)
      assert.equals(2, #blocks)
      assert.equals(3, #blocks[1].header)
      assert.equals("file1.txt", blocks[1].file)
      assert.equals(1, #blocks[1].hunks)
      assert.equals(0, blocks[1].hunks[1].line)
      assert.equals(3, #blocks[2].header)
      assert.equals("file2.txt", blocks[2].file)
      assert.equals(1, #blocks[2].hunks)
      assert.equals(1, blocks[2].hunks[1].line)
    end)

    it("parses combined diff format (merge commits)", function()
      local lines = {
        "diff --cc file.txt",
        "index abc,def..123",
        "--- a/file.txt",
        "+++ b/file.txt",
        "@@@ -10,5 -12,3 +10,6 @@@ context",
        "  unchanged in all",
        "--removed from parent 1",
        " -removed from parent 2",
        "++added in merge",
      }

      local blocks = diff.parse(lines)
      assert.equals(1, #blocks)
      assert.equals("file.txt", blocks[1].file)
      assert.equals(1, #blocks[1].hunks)
      assert.equals(10, blocks[1].hunks[1].line) -- third position (+10)
    end)

    it("parses multiple files", function()
      local lines = {
        "diff --git a/file1.txt b/file1.txt",
        "--- a/file1.txt",
        "+++ b/file1.txt",
        "@@ -1,1 +1,1 @@",
        "-old1",
        "+new1",
        "diff --git a/file2.txt b/file2.txt",
        "--- a/file2.txt",
        "+++ b/file2.txt",
        "@@ -1,1 +1,1 @@",
        "-old2",
        "+new2",
      }

      local blocks = diff.parse(lines)
      assert.equals(2, #blocks)
      assert.equals("file1.txt", blocks[1].file)
      assert.equals("file2.txt", blocks[2].file)
    end)

    it("parses multiple hunks per file", function()
      local lines = {
        "diff --git a/file.txt b/file.txt",
        "--- a/file.txt",
        "+++ b/file.txt",
        "@@ -1,1 +1,1 @@",
        "-old1",
        "+new1",
        "@@ -10,1 +10,1 @@",
        "-old2",
        "+new2",
      }

      local blocks = diff.parse(lines)
      assert.equals(1, #blocks)
      assert.equals(2, #blocks[1].hunks)
      assert.equals(1, blocks[1].hunks[1].line)
      assert.equals(10, blocks[1].hunks[2].line)
    end)

    it("sorts hunks by line number", function()
      local lines = {
        "diff --git a/file.txt b/file.txt",
        "--- a/file.txt",
        "+++ b/file.txt",
        "@@ -50,1 +50,1 @@",
        "-old2",
        "@@ -10,1 +10,1 @@",
        "-old1",
      }

      local blocks = diff.parse(lines)
      assert.equals(2, #blocks[1].hunks)
      assert.equals(10, blocks[1].hunks[1].line) -- sorted
      assert.equals(50, blocks[1].hunks[2].line)
    end)

    it("handles binary files", function()
      local lines = {
        "diff --git a/image.png b/image.png",
        "index abc123..def456 100644",
        "Binary files a/image.png and b/image.png differ",
      }

      local blocks = diff.parse(lines)
      assert.equals(1, #blocks)
      assert.equals("image.png", blocks[1].file)
      assert.equals(3, #blocks[1].header) -- diff line + binary notice
      assert.equals(0, #blocks[1].hunks) -- no hunks for binary
    end)

    it("handles binary files with prefixes in the path", function()
      local lines = {
        "diff --git a/ b/image.png b/ b/image.png",
        "index abc123..def456 100644",
        "Binary files a/image.png and b/image.png differ",
      }

      local blocks = diff.parse(lines)
      assert.equals(1, #blocks)
      assert.equals(" b/image.png", blocks[1].file)
      assert.equals(3, #blocks[1].header) -- diff line + binary notice
      assert.equals(0, #blocks[1].hunks) -- no hunks for binary
    end)

    it("handles pure renames", function()
      local lines = {
        "diff --git a/old.txt b/new.txt",
        "similarity index 100%",
        "rename from old.txt",
        "rename to new.txt",
      }

      local blocks = diff.parse(lines)
      assert.equals(1, #blocks)
      assert.equals("new.txt", blocks[1].file)
      assert.equals(4, #blocks[1].header)
      assert.equals(0, #blocks[1].hunks)
    end)

    it("handles renames with a diff", function()
      local lines = {
        "diff --git a/old.txt b/new.txt",
        "similarity index 66%",
        "rename from old.txt",
        "rename to new.txt",
        "--- a/old.text",
        "+++ b/new.txt",
        "@@ -1,3 +1,3 @@",
        "-line0",
        " line1",
        " line2",
        "+line3",
      }

      local blocks = diff.parse(lines)
      assert.equals(1, #blocks)
      assert.equals("new.txt", blocks[1].file)
      assert.equals(6, #blocks[1].header)
      assert.equals(1, #blocks[1].hunks)
    end)

    it("handles mode changes", function()
      local lines = {
        "diff --git a/script.sh b/script.sh",
        "old mode 100644",
        "new mode 100755",
      }

      local blocks = diff.parse(lines)
      assert.equals(1, #blocks)
      assert.equals("script.sh", blocks[1].file)
      assert.equals(3, #blocks[1].header)
      assert.equals(0, #blocks[1].hunks)
    end)

    it("handles deleted files", function()
      local lines = {
        "diff --git a/deleted.txt b/deleted.txt",
        "deleted file mode 100644",
        "index abc123..0000000",
        "--- a/deleted.txt",
        "+++ /dev/null",
        "@@ -1,3 +0,0 @@",
        "-line1",
        "-line2",
        "-line3",
      }

      local blocks = diff.parse(lines)
      assert.equals(1, #blocks)
      assert.equals("deleted.txt", blocks[1].file)
      assert.equals(1, #blocks[1].hunks)
      assert.equals(0, blocks[1].hunks[1].line) -- deleted at line 0
    end)

    it("handles new files", function()
      local lines = {
        "diff --git a/new.txt b/new.txt",
        "new file mode 100644",
        "index 0000000..abc123",
        "--- /dev/null",
        "+++ b/new.txt",
        "@@ -0,0 +1,3 @@",
        "+line1",
        "+line2",
        "+line3",
      }

      local blocks = diff.parse(lines)
      assert.equals(1, #blocks)
      assert.equals("new.txt", blocks[1].file)
      assert.equals(1, #blocks[1].hunks)
      assert.equals(1, blocks[1].hunks[1].line)
    end)

    it("ignores empty lines before diff", function()
      local lines = {
        "",
        "  ",
        "diff --git a/file.txt b/file.txt",
        "--- a/file.txt",
        "+++ b/file.txt",
        "@@ -1,1 +1,1 @@",
        "-old",
        "+new",
      }

      local blocks = diff.parse(lines)
      assert.equals(1, #blocks)
      assert.equals("file.txt", blocks[1].file)
    end)

    it("handles files with spaces in name", function()
      local lines = {
        "diff --git a/dir c/my file.txt b/dir c/my file.txt",
        "--- a/dir c/my file.txt",
        "+++ b/dir c/my file.txt",
        "@@ -1,1 +1,1 @@",
        "-old",
        "+new",
      }

      local blocks = diff.parse(lines)
      assert.equals(1, #blocks)
      assert.equals("dir c/my file.txt", blocks[1].file)
    end)

    it("handles quoted filenames", function()
      local lines = {
        'diff --git "a/my file.txt" "b/my file.txt"',
        '--- "a/my file.txt"',
        '+++ "b/my file.txt"',
        "@@ -1,1 +1,1 @@",
        "-old",
        "+new",
      }

      local blocks = diff.parse(lines)
      assert.equals(1, #blocks)
      assert.equals("my file.txt", blocks[1].file)
    end)

    it("handles files in subdirectories", function()
      local lines = {
        "diff --git a/path/to/file.txt b/path/to/file.txt",
        "--- a/path/to/file.txt",
        "+++ b/path/to/file.txt",
        "@@ -1,1 +1,1 @@",
        "-old",
        "+new",
      }

      local blocks = diff.parse(lines)
      assert.equals(1, #blocks)
      assert.equals("path/to/file.txt", blocks[1].file)
    end)

    it("handles single-line changes in hunk header", function()
      local lines = {
        "diff --git a/file.txt b/file.txt",
        "--- a/file.txt",
        "+++ b/file.txt",
        "@@ -5 +5 @@",
        "-old",
        "+new",
      }

      local blocks = diff.parse(lines)
      assert.equals(1, #blocks)
      assert.equals(1, #blocks[1].hunks)
      assert.equals(5, blocks[1].hunks[1].line)
    end)

    it("preserves diff content including - and + prefixes", function()
      local lines = {
        "diff --git a/file.txt b/file.txt",
        "--- a/file.txt",
        "+++ b/file.txt",
        "@@ -1,3 +1,3 @@",
        " context",
        "-removed",
        "+added",
      }

      local blocks = diff.parse(lines)
      local hunk_diff = blocks[1].hunks[1].diff
      assert.equals("@@ -1,3 +1,3 @@", hunk_diff[1])
      assert.equals(" context", hunk_diff[2])
      assert.equals("-removed", hunk_diff[3])
      assert.equals("+added", hunk_diff[4])
    end)

    it("handles empty hunks (just @@ header)", function()
      local lines = {
        "diff --git a/file.txt b/file.txt",
        "--- a/file.txt",
        "+++ b/file.txt",
        "@@ -1,0 +1,0 @@",
        "@@ -10,1 +10,1 @@",
        "-old",
      }

      local blocks = diff.parse(lines)
      assert.equals(1, #blocks)
      assert.equals(2, #blocks[1].hunks)
      assert.equals(1, #blocks[1].hunks[1].diff) -- just the @@ line
      assert.equals(2, #blocks[1].hunks[2].diff) -- @@ + one line
    end)

    it("handles context-only hunks (no changes, just context)", function()
      local lines = {
        "diff --git a/file.txt b/file.txt",
        "--- a/file.txt",
        "+++ b/file.txt",
        "@@ -1,3 +1,3 @@",
        " context line 1",
        " context line 2",
        " context line 3",
      }

      local blocks = diff.parse(lines)
      assert.equals(1, #blocks)
      assert.equals(1, #blocks[1].hunks)
      assert.equals(4, #blocks[1].hunks[1].diff)
    end)

    it("handles hunk at line 0 (insertion at start)", function()
      local lines = {
        "diff --git a/file.txt b/file.txt",
        "--- a/file.txt",
        "+++ b/file.txt",
        "@@ -0,0 +1,2 @@",
        "+line1",
        "+line2",
      }

      local blocks = diff.parse(lines)
      assert.equals(1, blocks[1].hunks[1].line)
    end)

    it("handles very long filenames", function()
      local long_path = "very/long/path/with/many/segments/" .. string.rep("a", 200) .. ".txt"
      local lines = {
        "diff --git a/" .. long_path .. " b/" .. long_path,
        "--- a/" .. long_path,
        "+++ b/" .. long_path,
        "@@ -1,1 +1,1 @@",
        "-old",
        "+new",
      }

      local blocks = diff.parse(lines)
      assert.equals(1, #blocks)
      assert.equals(long_path, blocks[1].file)
    end)

    it("handles unicode in filenames", function()
      local lines = {
        "diff --git a/文件.txt b/文件.txt",
        "--- a/文件.txt",
        "+++ b/文件.txt",
        "@@ -1,1 +1,1 @@",
        "-old",
        "+new",
      }

      local blocks = diff.parse(lines)
      assert.equals(1, #blocks)
      assert.equals("文件.txt", blocks[1].file)
    end)

    it("handles truncated/incomplete diff gracefully", function()
      local lines = {
        "diff --git a/file.txt b/file.txt",
        "--- a/file.txt",
        "+++ b/file.txt",
        "@@ -1,5 +1,5 @@",
        " context",
        "-old",
        -- Missing rest of hunk
      }

      -- Should not crash
      local blocks = diff.parse(lines)
      assert.equals(1, #blocks)
      assert.equals(1, #blocks[1].hunks)
    end)

    it("handles mixed plain and git diffs", function()
      local lines = {
        "--- plain1.txt",
        "+++ plain1.txt",
        "@@ -1,1 +1,1 @@",
        "-old",
        "+new",
        "diff --git a/git1.txt b/git1.txt",
        "--- a/git1.txt",
        "+++ b/git1.txt",
        "@@ -1,1 +1,1 @@",
        "-old",
        "+new",
        "--- plain2.txt",
        "+++ plain2.txt",
        "@@ -1,1 +1,1 @@",
        "-old",
        "+new",
        "diff --git a/git2.txt b/git2.txt",
        "--- a/git2.txt",
        "+++ b/git2.txt",
        "@@ -1,1 +1,1 @@",
        "-old",
        "+new",
      }

      local blocks = diff.parse(lines)
      assert.equals(4, #blocks)
      assert.equals("plain1.txt", blocks[1].file)
      assert.equals("git1.txt", blocks[2].file)
      assert.equals("plain2.txt", blocks[3].file)
      assert.equals("git2.txt", blocks[4].file)
    end)

    it("handles symlink changes", function()
      local lines = {
        "diff --git a/link.txt b/link.txt",
        "deleted file mode 120000",
        "--- a/link.txt",
        "+++ /dev/null",
        "@@ -1 +0,0 @@",
        "-target.txt",
      }

      local blocks = diff.parse(lines)
      assert.equals(1, #blocks)
      assert.equals("link.txt", blocks[1].file)
    end)

    it("handles files with only newline changes", function()
      local lines = {
        "diff --git a/file.txt b/file.txt",
        "--- a/file.txt",
        "+++ b/file.txt",
        "@@ -1 +1 @@",
        "-line",
        "\\ No newline at end of file",
        "+line",
      }

      local blocks = diff.parse(lines)
      assert.equals(1, #blocks)
      assert.equals(1, #blocks[1].hunks)
      -- Should include the "No newline" marker
      assert.truthy(vim.tbl_contains(blocks[1].hunks[1].diff, "\\ No newline at end of file"))
    end)

    it("handles diff with no file changes (same content)", function()
      local lines = {
        "diff --git a/file.txt b/file.txt",
        "index abc123..abc123 100644",
        "--- a/file.txt",
        "+++ b/file.txt",
      }

      local blocks = diff.parse(lines)
      assert.equals(1, #blocks)
      assert.equals(0, #blocks[1].hunks) -- no hunks = no changes
    end)
  end)
end)
