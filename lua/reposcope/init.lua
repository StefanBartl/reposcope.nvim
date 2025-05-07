--- @class UIStart Functions to start and close the Reposcope UI
--- @field setup fun(opts: table|nil): nil Initializes the UI and performs prechecks
--- @field open_ui fun(): nil Opens the Reposcope UI: Captures caller position, calls the window factory functions and sets keymaps
--- @field close_ui fun(): nil Closes the Reposcope UI: Set focus back to caller position, close all windows and unset keymaps
local M = {}

local config = require("reposcope.config")
local checks = require("reposcope.utils.checks")
local ui_state = require("reposcope.state.ui")
local background = require("reposcope.ui.background")
local preview = require("reposcope.ui.preview.init")
local list = require("reposcope.ui.list.init")
local prompt = require("reposcope.ui.prompt.init")
local keymaps =  require("reposcope.keymaps")
-- Ensure user commands are registered
require("reposcope.usercommands")


--- Initializes the Reposcope UI by applying user options and performing tool checks.
--- This function should be called once during plugin setup.
---
--- @param opts table|nil Optional configuration options to override defaults
--- @return nil
function M.setup(opts)
  config.setup(opts or {})
  checks.resolve_request_tool()
end

function M.open_ui()
  ui_state.capture_invocation_state()
  background.open_backgd()
  preview.open_preview()
  prompt.open_prompt()
  list.open_list()
  keymaps.set_ui_keymaps()
end

function M.close_ui()
  -- set focus back to caller position
  if vim.api.nvim_win_is_valid(ui_state.invocation.win) then
    vim.api.nvim_set_current_win(ui_state.invocation.win)
    vim.api.nvim_win_set_cursor(ui_state.invocation.win, {
      ui_state.invocation.cursor.row,
      ui_state.invocation.cursor.col,
    })
  end

  -- close all windows
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local ok_buf, buf = pcall(vim.api.nvim_win_get_buf, win)
    if ok_buf and vim.api.nvim_buf_is_valid(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      if name:find("^reposcope://") then
        vim.api.nvim_win_close(win, true)
      end
    end
  end

   keymaps.unset_ui_keymaps()
   vim.cmd("stopinsert")
end

return M
