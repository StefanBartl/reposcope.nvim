---@module 'reposcope.init'
---@brief Initializes, opens, and manages the main Reposcope UI lifecycle.
---@description
--- This module serves as the main entry point for Reposcope’s UI initialization.
--- It applies user-defined configuration, sets up and opens the main UI components
--- (background, prompt, preview, list), manages keymaps and autocmds, and ensures
--- proper teardown via `close_ui()`. It delegates UI responsibilities to submodules
--- while handling coordination and lifecycle orchestration.
---
--- Key Responsibilities:
--- - Calling `config.setup()` with user `ConfigOptions`
--- - Opening all Reposcope UI windows and setting keymaps (`open_ui`)
--- - Capturing and restoring the user's cursor/window context
--- - Closing all Reposcope-related buffers and windows cleanly
--- - Registering and removing autocmds for automatic teardown (`QuitPre`)
---
--- This module is expected to be called from your plugin’s top-level `.setup()` call.

---@class UIInit : UIInitModule
local M = {}

-- Vim Utilities
local nvim_set_current_win = vim.api.nvim_set_current_win
local nvim_buf_is_valid = vim.api.nvim_buf_is_valid
local nvim_win_set_cursor = vim.api.nvim_win_set_cursor
local nvim_win_is_valid = vim.api.nvim_win_is_valid
-- Project-specific Configuration and Utility Modules
local config = require("reposcope.config")
local checks = require("reposcope.utils.checks")
local notify = require("reposcope.utils.debug").notify
-- State Modules (State Management)
local ui_state = require("reposcope.state.ui.ui_state")
-- UI Components (Core UI Elements)
local background = require("reposcope.ui.background.background_window")
local list = require("reposcope.ui.list.init")
local preview = require("reposcope.ui.preview.init")
local prompt = require("reposcope.ui.prompt.init")
-- UI-Specific Functions and Submodules
local list_window = require("reposcope.ui.list.list_window")
local prompt_autocmds = require("reposcope.ui.prompt.prompt_autocmds")
-- Keymaps and User Input
local keymaps = require("reposcope.bindings.keymaps")
local ui_autocmds = require("reposcope.bindings.autocmds")

-- Ensure user commands are registered
require("reposcope.bindings.usrcmds")

---Initializes the Reposcope UI by applying user options and performing tool checks.
--- This function should be called once during plugin setup.
---@param opts PartialConfigOptions Optional configuration options to override defaults
function M.setup(opts)
  config.setup(opts or {})
  checks.resolve_request_tool()

  local keymaps_opt = config.get_option("keymaps")
  if keymaps_opt ~= false then keymaps.set_user_keymaps(keymaps_opt, config.get_option("keymap_opts")) end

  -- Preload file-cached READMEs into RAM: the file cache survives restarts,
  -- but without this a fresh session still pays a disk read on the first
  -- navigation to each repository even though the content was already there.
  require("reposcope.cache.readme_cache").warm_ram_from_file_cache()

  -- Tell hover.nvim that `owner/repo` is a target, when it is one reposcope
  -- has cached. Soft: without hover.nvim this does nothing, and hover.nvim
  -- never names this plugin -- contributions arrive through its registry.
  -- `hover = false` in the spec turns it off.
  if config.get_option("hover") ~= false then require("reposcope.hover").setup() end
end

---Opens the Reposcope UI. Captures caller position, creates background, preview, list, and prompt windows, and sets keymaps.
---@return nil
function M.open_ui()
  notify("[reposcope] REPOSCOPE START")

  -- Size the UI to the editor as it is NOW. Every layout module used to
  -- compute its geometry once, when it was first required, so a terminal
  -- resized after that point left the picker opening at the old size for the
  -- rest of the session. The order matters: the four dependents read
  -- `ui_config`, so it has to go first.
  require("reposcope.ui.config").recompute()
  require("reposcope.ui.list.list_config").recompute()
  require("reposcope.ui.preview.preview_config").recompute()
  require("reposcope.ui.prompt.prompt_config").recompute()
  require("reposcope.ui.background.background_config").recompute()

  notify("[reposcope] CAPTURING SEQUENCE")
  -- Capture users window and cursor for placing him back after closing Reposcope UI
  ui_state.capture_invocation_state()

  notify("[reposcope] BACKGROUND SEQUENCE")
  -- Open Background
  background.open_window()

  notify("[reposcope] LIST SEQUENCE")
  -- Open List
  list.initialize()

  notify("[reposcope] PREVIEW SEQUENCE")
  -- Open Preview
  preview.initialize()

  notify("[reposcope] PROMPT SEQUENCE")
  -- Open Prompt
  prompt.initialize()

  notify("[reposcope] START VIEW SEQUENCE")
  -- Show favorites (if any) instead of starting from an empty list
  require("reposcope.controllers.start_view_controller").show_favorites_if_any()

  notify("[reposcope] KEYMAPS SEQUENCE")
  -- Set Keymaps
  keymaps.set_ui_keymaps()

  notify("[reposcope] SETUP UI CLOSE SEQUENCE")
  -- Setup UI Close Handler
  M.setup_ui_close()

  notify("[reposcope] REPOSCOPE START SEQUENCE FINISHED")
end

---Closes the Reposcope UI. Restores the caller window, closes all Reposcope windows, and unsets keymaps.
---@return nil
function M.close_ui()
  -- A drawn README image sits on the terminal grid, not in a buffer, so
  -- deleting the buffers below does not take it with them. Clear it first,
  -- while the windows this ran against still exist.
  require("reposcope.ui.preview.preview_image").clear()

  -- save row number in list
  ui_state.list.last_selected_line = list_window.highlighted_line

  -- set focus back to caller position
  if nvim_win_is_valid(ui_state.invocation.win) then
    nvim_set_current_win(ui_state.invocation.win)
    nvim_win_set_cursor(ui_state.invocation.win, {
      ui_state.invocation.cursor.row,
      ui_state.invocation.cursor.col,
    })
  end

  -- Close all Reposcope-related buffers as well
  local bufs = ui_state.get_buffers()
  if bufs then
    for i = 1, #bufs do
      if nvim_buf_is_valid(bufs[i]) then vim.api.nvim_buf_delete(bufs[i], { force = true }) end
    end
  else
    notify("[reposcope] No bufs available to close", 4)
  end

  prompt_autocmds.cleanup_autocmds()
  keymaps.unset_ui_keymaps()
  M.remove_ui_autocmd()

  notify("[reposcope] REPOSCOPE END")

  vim.cmd("stopinsert")
end

---Sets up an AutoCmd for automatically closing all related UI windows (Reposcope UI).
--- The AutoCmd triggers on `QuitPre` for any window that matches the pattern `reposcope://*`.
--- If one of these windows is closed (via :q, :q!, or :wq), all related UI windows are closed.
--- Delegates to `reposcope.bindings.autocmds`.
---@return nil
function M.setup_ui_close() ui_autocmds.setup_ui_close(M.close_ui) end

---Removes the AutoCmd for automatically closing all related UI windows (Reposcope UI).
--- This prevents the UI from being closed automatically when :q or :q! is used.
--- Delegates to `reposcope.bindings.autocmds`.
---@return nil
function M.remove_ui_autocmd() ui_autocmds.remove_ui_autocmd() end

return M
