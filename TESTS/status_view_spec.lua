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

  -- Every highlight span has to start on text, never on padding — centring puts
  -- blanks on both sides of a cell, which is exactly what a span computed from
  -- the column edge would colour instead of the word.
  for _, h in ipairs(hls) do
    if h.hl ~= "ReposcopeStatusHeader" and h.hl ~= "ReposcopeStatusMark" then
      local row = lines[h.row + 1]
      H.ok(row:sub(h.col + 1, h.col + 1) ~= " ", ("the %s span starts on text"):format(h.hl))
      H.ok(row:sub(h.end_col, h.end_col) ~= " ", ("the %s span ends on text"):format(h.hl))
    end
  end

  -- Repository names are the column the eye scans, so they stay left-aligned
  -- against the gutter; everything else is centred under its heading.
  for i = 2, #lines do
    H.eq(lines[i]:sub(3, 3), lines[i]:match("^  (%S)"), "row " .. i .. "'s name starts flush left")
  end

  -- Centres are compared with a one-cell tolerance: a cell whose width has the
  -- opposite parity to its column cannot sit exactly on the axis, and the odd
  -- cell deliberately goes to the right.
  local function cell_center(line, needle)
    local from, to = line:find(needle, 1, true)
    return (from + to) / 2
  end
  local function centered(heading, value, msg)
    local drift = math.abs(cell_center(lines[1], heading) - cell_center(lines[2], value))
    H.ok(drift <= 1, ("%s (off by %s cells)"):format(msg, drift))
  end
  centered("STATE", "clean", "a state value shares the centre of its heading")
  centered("LAST COMMIT", "2h", "so does an age value")

  -- The header keeps its trailing padding: its highlight is underlined, and
  -- that underline is the rule under the whole table.
  H.ok(#lines[1] > #lines[2]:gsub("%s+$", ""), "the header spans the full table width")
  H.excludes(lines[2], "  \n", "data rows are trimmed")

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

  -- winbar legend -------------------------------------------------------------
  -- The legend is a `%!` expression so it re-fits on resize; what matters is
  -- that it never overflows (Neovim would truncate it from the left, leaving a
  -- bare `<` where `<CR> README` used to be) and never drops `? Keys`, which is
  -- how everything it *did* drop stays reachable.
  local winbar = vim.api.nvim_get_option_value("winbar", { win = 0 })
  H.contains(winbar, "%!", "the winbar is an expression, not a frozen string")

  vim.cmd("vsplit")
  local filler = vim.api.nvim_get_current_win()
  local status_win = vim.fn.bufwinid(buf)
  vim.api.nvim_set_current_win(status_win)
  vim.o.winminwidth = 1

  for _, want in ipairs({ 74, 55, 30 }) do
    vim.api.nvim_win_set_width(status_win, want)
    local width = vim.api.nvim_win_get_width(status_win)
    local text = vim.api.nvim_eval_statusline(winbar, { winid = status_win, use_winbar = true }).str
    H.ok(vim.fn.strdisplaywidth(text) <= width, ("the legend fits a window of %d"):format(width))
    H.contains(text, "? Keys", ("? Keys survives a window of %d"):format(width))
    if text:match("^%s*(.)") == "<" then
      H.contains(text, "<CR>", ("the legend is not truncated at %d"):format(width))
    end
  end

  vim.api.nvim_win_close(filler, true)
end
