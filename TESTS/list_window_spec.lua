-- TESTS/list_window_spec.lua — reposcope.ui.list.list_window's viewport handling.
--
-- The selection in the list is an extmark, not a cursor: the user stays in the
-- prompt and the list window is never entered. That makes the list window's own
-- cursor the only thing that can scroll it, and nothing was moving it — so a
-- search with more results than the window is tall highlighted rows below the
-- fold and the list sat there looking frozen. `reveal_line` is what moves it,
-- and `highlight_selected` has to call it, so both are covered here.
--
-- The window is built by hand rather than through `open_window`, whose float
-- geometry is derived from `vim.o.columns`/`vim.o.lines`; a headless 80x24
-- would make "is line 80 visible" depend on the terminal that ran the suite.

return function(H)
  local lw = require("reposcope.ui.list.list_window")
  local ui_state = require("reposcope.state.ui.ui_state")

  local HEIGHT = 10
  local TOTAL = 100

  ---Opens a scratch list window holding `TOTAL` numbered rows.
  ---@return integer win, fun() close
  local function open()
    local buf = vim.api.nvim_create_buf(false, true)
    local lines = {}
    for i = 1, TOTAL do
      lines[i] = ("owner/repo-%d: description %d"):format(i, i)
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    local win = vim.api.nvim_open_win(buf, false, {
      relative = "editor",
      row = 0,
      col = 0,
      width = 40,
      height = HEIGHT,
      style = "minimal",
    })
    vim.wo[win].scrolloff = 3 -- What `apply_layout` sets

    ui_state.buffers.list = buf
    ui_state.windows.list = win

    local function close()
      if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
      ui_state.buffers.list = nil
      ui_state.windows.list = nil
    end

    return win, close
  end

  ---The window's first and last visible line.
  ---@param win integer
  ---@return integer top, integer bot
  local function viewport(win) return vim.fn.line("w0", win), vim.fn.line("w$", win) end

  -- The window follows the highlight past the fold ---------------------------
  do
    local win, close = open()

    lw.highlight_selected(1)
    H.eq(vim.api.nvim_win_get_cursor(win)[1], 1, "the first row starts under the cursor")

    lw.highlight_selected(80)
    H.eq(lw.highlighted_line, 80, "the highlight moved")
    H.eq(vim.api.nvim_win_get_cursor(win)[1], 80, "and the window's cursor moved with it")

    local top, bot = viewport(win)
    H.ok(top <= 80 and 80 <= bot, ("row 80 is on screen (showing %d..%d)"):format(top, bot))

    -- Back up, and the view has to follow in the other direction too.
    lw.highlight_selected(2)
    top, bot = viewport(win)
    H.ok(top <= 2 and 2 <= bot, ("row 2 is on screen again (showing %d..%d)"):format(top, bot))

    close()
  end

  -- The last row is reachable, scrolloff notwithstanding ----------------------
  do
    local win, close = open()

    lw.highlight_selected(TOTAL)
    H.eq(vim.api.nvim_win_get_cursor(win)[1], TOTAL, "the final row is selectable")
    local top, bot = viewport(win)
    H.ok(top <= TOTAL and TOTAL <= bot, ("the final row is on screen (showing %d..%d)"):format(top, bot))

    close()
  end

  -- `set_highlighted_line` scrolls as well ------------------------------------
  do
    local win, close = open()

    lw.set_highlighted_line(60)
    H.eq(vim.api.nvim_win_get_cursor(win)[1], 60, "the other highlight entry point scrolls too")

    close()
  end

  -- Out-of-range and missing windows are answered, not raised -----------------
  do
    local win, close = open()

    lw.reveal_line(TOTAL + 500)
    H.eq(vim.api.nvim_win_get_cursor(win)[1], TOTAL, "a row past the end clamps to the last one")

    lw.reveal_line(0)
    H.eq(vim.api.nvim_win_get_cursor(win)[1], 1, "and a row before the start clamps to the first")

    ---@diagnostic disable-next-line: param-type-mismatch
    lw.reveal_line(nil)
    H.eq(vim.api.nvim_win_get_cursor(win)[1], 1, "a non-number is ignored")

    close()
  end

  do
    -- No list window at all: navigation still happens, it just has nothing to
    -- scroll. This is the state between `close_window` and the next search.
    ui_state.buffers.list = nil
    ui_state.windows.list = nil
    lw.reveal_line(5) -- Must not raise
  end
end
