---@desc forward declarations
local default, apply_list_highlight

---@class UIList Creates and manages the floating repository list window in the Reposcope UI.
---@field open_list fun(): nil Creates a scratch buffer named `reposcope://list`, fills it with predefined repository lines and opens the repository floating list window in the Reposcope UI
---@field private default fun(): nil Creates the default floating list window
---@field private apply_list_highlight fun(win: number): nil Applies highlight settings to the list window

local M = {}

local config = require("reposcope.config")
local ui_config = require("reposcope.ui.config")
local ui_state = require("reposcope.state.ui")
local protected = require("reposcope.utils.protection")
local prompt_config = require("reposcope.ui.prompt.config")
local notify = require("reposcope.utils.debug").notify

---Creates and opens the floating list window for repositories
function M.open_list()
  ui_state.buffers.list = protected.create_named_buffer("reposcope://list")
  vim.bo[ui_state.buffers.list].modifiable = false

  if config.options.layout == "default" then
    default()
  else
    notify("Unknown layout: " .. config.options.layout, 3)
  end
end

---Creates the default floating list window
function default()
  ui_state.windows.list = vim.api.nvim_open_win(ui_state.buffers.list, false, {
    relative = "editor",
    row = ui_config.row + prompt_config.height + 1,
    col = ui_config.col + 1,
    width = (ui_config.width / 2) - 1,
    height = ui_config.height - prompt_config.height - 2,
    --title = "Repositories",
    --title_pos = "left",
    border = "none",
    style = "minimal",
    focusable = false,
    noautocmd = true,
  })
  apply_list_highlight(ui_state.windows.list)
end

---Applies highlight settings to the list window
---@param win number The window ID of the list window
function apply_list_highlight(win)
  local ns = vim.api.nvim_create_namespace("reposcope_list")
  vim.api.nvim_set_hl(ns, "Normal", { bg = ui_config.colortheme.backg })
  vim.api.nvim_win_set_hl_ns(win, ns)

  vim.api.nvim_set_hl(0, "ReposcopeListHighlight", {
    bg = "#44475a",
    fg = "#ffffff",
    bold = true,
  })
end

return M
