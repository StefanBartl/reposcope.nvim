-- TESTS/status_view_spec.lua — the status overview's rendering and its marks.
--
-- Rendering is where the column offsets are computed by hand (byte offsets for
-- the highlights, display cells for the alignment), and marks add a gutter in
-- front of every one of them — so the two are tested together: a mark must
-- change what the first two cells say and nothing else about the row.
--
-- The keys are exercised through `:normal`, not by calling the handlers, since
-- what is being checked is that they are actually bound to the status buffer.

return function(H)
  local sv = require("reposcope.ui.actions.status_view")

  ---@param name string
  ---@param branch string
  ---@param state string
  ---@param ahead integer
  ---@return RepoStatusRecord
  local function rec(name, branch, state, ahead)
    return {
      name = name,
      path = "/fixture/" .. name,
      branch = branch,
      ahead = ahead,
      behind = 0,
      has_upstream = true,
      dirty = state == "dirty" and 2 or 0,
      state = state,
      last_commit = os.time() - 7200,
    }
  end

  local records = {
    rec("charlie", "main", "clean", 0),
    rec("alpha", "feature/a-very-long-branch-name-indeed", "dirty", 0),
    rec("bravo", "main", "ahead", 2),
  }

  -- render --------------------------------------------------------------------
  local lines, hls = sv.render(records)
  H.eq(#lines, 4, "one header line plus one line per repository")
  H.contains(lines[1], "REPOSITORY", "the header names the first column")

  for i, line in ipairs(lines) do
    H.eq(line:sub(1, 2), "  ", "row " .. i .. " opens with the blank mark gutter")
  end

  -- The repository-name highlight has to start on the name, not on the gutter
  -- or on padding: it is the span most likely to break when the offsets move.
  for _, h in ipairs(hls) do
    if h.hl == "ReposcopeStatusRepo" then
      local row = lines[h.row + 1]
      H.ok(row:sub(h.col + 1, h.col + 1) ~= " ", "the repo highlight starts on the name")
    end
  end

  -- summary -------------------------------------------------------------------
  local summary = sv.summary(records)
  H.contains(summary, "3 repos", "the summary counts the repositories")
  H.contains(summary, "1 dirty", "and calls out the dirty one")
  H.excludes(summary, "marked", "with nothing marked, nothing is said about marks")

  -- marks ---------------------------------------------------------------------
  sv.show(records, { output = "buffer" })
  local buf = vim.api.nvim_get_current_buf()

  local function row(n) return vim.api.nvim_buf_get_lines(buf, n - 1, n, false)[1] end

  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.cmd("normal m")
  H.eq(row(2):sub(1, 4), "✓ ", "m marks the row under the cursor")
  H.eq(row(3):sub(1, 2), "  ", "and leaves its neighbour alone")
  H.eq(vim.fn.strdisplaywidth(row(2)), vim.fn.strdisplaywidth(lines[2]), "marking must not shift the columns sideways")
  H.contains(sv.summary(records), "1 marked", "the summary picks the mark up")

  vim.cmd("normal m")
  H.eq(row(2):sub(1, 2), "  ", "m again clears it")

  -- A mark belongs to a repository, not to a row: the sort cycle reorders the
  -- records in place, and the tick has to travel with `charlie`.
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.cmd("normal m")
  H.contains(row(2), "charlie", "charlie starts in discovery order at the top")
  vim.cmd("normal s") -- discovery -> name
  local marked_row
  for n = 2, 4 do
    if row(n):sub(1, 4) == "✓ " then marked_row = row(n) end
  end
  H.ok(marked_row, "the mark survives a re-sort")
  H.contains(marked_row, "charlie", "and is still on the same repository")

  -- M is both directions: mark everything, then clear everything.
  vim.cmd("normal M")
  for n = 2, 4 do
    H.eq(row(n):sub(1, 4), "✓ ", "M marks every repository")
  end
  vim.cmd("normal M")
  for n = 2, 4 do
    H.eq(row(n):sub(1, 2), "  ", "and M again clears them all")
  end

  -- Visual mode marks the rows the selection spans, and only those.
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.cmd("normal Vjm")
  H.eq(row(2):sub(1, 4), "✓ ", "the first selected row is marked")
  H.eq(row(3):sub(1, 4), "✓ ", "so is the second")
  H.eq(row(4):sub(1, 2), "  ", "and the selection does not overshoot")
  vim.cmd("normal M")
  vim.cmd("normal M")

  -- Every documented key is really bound to the buffer.
  local normal_maps = {}
  for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
    normal_maps[m.lhs] = true
  end
  for _, lhs in ipairs({ "p", "P", "f", "m", "M", "gp", "gP", "gf", "gu", "S", "s", "r", "R", "y", "?" }) do
    H.ok(normal_maps[lhs], "normal-mode key " .. lhs .. " is bound")
  end

  local visual_maps = {}
  for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "x")) do
    visual_maps[m.lhs] = true
  end
  H.ok(visual_maps["m"], "m is bound in Visual mode too")
end
