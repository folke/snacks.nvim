local M = {}

---@param opts snacks.picker.tags.Config
---@type snacks.picker.finder
function M.tags(opts, ctx)
  if opts.need_search ~= false and ctx.filter.search == "" then
    return function() end
  end

  local tags = vim.fn.taglist(ctx.filter.search)

  local items = {} ---@type snacks.picker.finder.Item[]
  local temp_bufs = {}
  for _, tag in ipairs(tags) do
    ---@type snacks.picker.finder.Item
    ---@diagnostic disable-next-line: missing-fields
    local item = {}
    item = {
      text = tag.name,
      name = tag.name,
      kind = tag.kind,
      tag = tag,
      file = tag.filename,
      resolve = function() -- this is kinda expensive, since we have to open a buffer to search for the location of the tag
        local scratch_buf
        if temp_bufs[tag.filename] == nil
        then
          scratch_buf = vim.api.nvim_create_buf(false, true)
          temp_bufs[tag.filename] = scratch_buf
          local ei = vim.o.eventignore
          vim.o.eventignore = "all"
          vim.bo[scratch_buf].filetype = "snacks_picker_tags"
          vim.o.eventignore = ei
          local file = io.open(tag.filename, "r")
          if not file then
            print("Could not open file: " .. tag.filename)
            return
          end
          local content = file:read("*a")
          file:close()

          vim.api.nvim_buf_set_lines(scratch_buf, 0, -1, false, vim.split(content, "\n"))
        else
          scratch_buf = temp_bufs[tag.filename]
        end
        vim.api.nvim_buf_call(scratch_buf, function()
          local search_cmd = string.gsub(string.gsub(tag.cmd, '^/', '\\M'), '/$', '')
          local search_res = vim.fn.searchpos(search_cmd, 'n')
          local line, col = search_res[1], search_res[2]
          local search_name_res = vim.fn.searchpos(
            '\\%' .. tostring(line) .. 'l'    -- search on the line from tag.cmd
            .. '\\%>' .. tostring(col) .. 'c' -- search on the col from tag.cmd
            .. tag.name, 'n'
          )
          local col_start = search_name_res[2]
          local col_end = col_start + vim.fn.strdisplaywidth(tag.name, col_start)
          local max_col = vim.fn.strdisplaywidth(vim.tbl_get(vim.api.nvim_buf_get_text(scratch_buf, line-1, 0, line-1, -1, {}), 1) or "")
          local col_start_2 = col_start - 1
          local col_end_2
          if col_start_2 < 0 then col_end_2 = col_end else col_end_2 = col_end - 1 end
          col_end_2 = math.min(max_col, col_end_2)

          item.line = line
          item.pos = { line, math.max(0, col_start_2) }
          item.end_pos = { line, math.max(0, col_end_2) }
          return item
        end)
      end,
    }
    items[#items + 1] = item
  end
  for _, tmp_buf in pairs(temp_bufs) do
    vim.api.nvim_buf_delete(tmp_buf, {})
  end
  return items
end

return M
