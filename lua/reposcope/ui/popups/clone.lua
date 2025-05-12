---@class ClonePopupUI
---@field open fun():nil Opens the clone popup ui
local M = {}

local config = require("reposcope.config")
local state = require("reposcope.state.popups")

---Opens the clone popup ui
function M.open()
  state.clone.buf = vim.api.nvim_create_buf(false, true)
  local width = math.min(vim.o.columns, 80)
  local heigth = 1
  local row = math.floor((vim.o.lines / 2) - (heigth / 2))
  local col = math.floor((vim.o.columns / 2) - (width / 2))

  state.clone.win = vim.api.nvim_open_win(state.clone.buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = heigth,
    border = "single",
    title = " Enter path for cloning ",
    title_pos = "center",
    style = "minimal",
  })

  local dir = config.get_clone_dir()

  vim.api.nvim_buf_set_lines(state.clone.buf, 0, -1, false, { dir })
  vim.api.nvim_set_current_win(state.clone.win)
  vim.api.nvim_win_set_cursor(state.clone.win, {1, #dir})
  vim.defer_fn(function()
    vim.cmd("startinsert!")
  end, 10)

  require("reposcope.keymaps").set_clone_keymaps()
end

return M
