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
local nvim_get_current_win = vim.api.nvim_get_current_win
local nvim_win_get_buf = vim.api.nvim_win_get_buf
local nvim_set_current_win = vim.api.nvim_set_current_win
local nvim_buf_is_valid = vim.api.nvim_buf_is_valid
local nvim_buf_get_name = vim.api.nvim_buf_get_name
local nvim_win_set_cursor = vim.api.nvim_win_set_cursor
local nvim_win_is_valid = vim.api.nvim_win_is_valid
local nvim_del_autocmd = vim.api.nvim_del_autocmd
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
local keymaps = require("reposcope.keymaps")


-- Ensure user commands are registered
require("reposcope.usercommands")
-- holding state for setup_ui_close and remove_ui_autocmd
local close_autocmd_id


---Initializes the Reposcope UI by applying user options and performing tool checks.
--- This function should be called once during plugin setup.
---@param opts PartialConfigOptions Optional configuration options to override defaults
function M.setup(opts)
  config.setup(opts or {})
  checks.resolve_request_tool()

  local keymaps_opt = config.get_option("keymaps")
  if keymaps_opt ~= false then
    keymaps.set_user_keymaps(keymaps_opt, config.get_option("keymap_opts"))
  end
end


---@private
---Clears the second line of each prompt buffer (in case user input or external message was inserted).
---@description
--- This function ensures that any unintended input (e.g. from `:messages` or stray keystrokes) is removed
--- from the actual input line of the prompt buffers (usually line index 1).
--- It temporarily makes the buffer modifiable, performs the deletion, and then restores the lock.
---@return nil
local function _clear_prompt_inputs()
  local bufs = ui_state.buffers.prompt
  if not bufs then return end

  for _, buf in pairs(bufs) do
    if type(buf) == "number" and vim.api.nvim_buf_is_valid(buf) then
      local line = vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1]
      if type(line) == "string" and line ~= "" then
        vim.bo[buf].modifiable = true
        vim.api.nvim_buf_set_lines(buf, 1, 2, false, { "" })
        vim.bo[buf].modifiable = false
      end
    end
  end
end


---Opens the Reposcope UI. Captures caller position, creates background, preview, list, and prompt windows, and sets keymaps.
---@return nil
function M.open_ui()
  notify("[reposcope] REPOSCOPE START")

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


  notify("[reposcope] KEYMAPS SEQUENCE")
  -- Set Keymaps
  keymaps.set_ui_keymaps()


  notify("[reposcope] SETUP UI CLOSE SEQUENCE")
  -- Setup UI Close Handler
  M.setup_ui_close()


  notify("[reposcope] CLEAR PROMPT INPUT SEQUENCE")
  -- Clears the prompt input fields from symbols not supposed to be in them
  _clear_prompt_inputs()

  notify("[reposcope] REPOSCOPE START SEQUENCE FINISHED")
end

---Closes the Reposcope UI. Restores the caller window, closes all Reposcope windows, and unsets keymaps.
---@return nil
function M.close_ui()
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
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if nvim_buf_is_valid(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      if type(name) == "string" and name:find("^reposcope://") then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end
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
--- The AutoCmd is stored with an ID (`close_autocmd_id`) for easy removal.
---@return nil
function M.setup_ui_close()
  if close_autocmd_id then
    vim.api.nvim_del_autocmd(close_autocmd_id)
  end

  close_autocmd_id = vim.api.nvim_create_autocmd("QuitPre", {
    callback = function()
      local win = nvim_get_current_win()
      local buf = nvim_win_get_buf(win)
      local buf_name = nvim_buf_get_name(buf)
      if buf_name:find("^reposcope://") then
        M.close_ui()
      end
    end,
  })
end

---Removes the AutoCmd for automatically closing all related UI windows (Reposcope UI).
--- This prevents the UI from being closed automatically when :q or :q! is used.
--- The AutoCmd ID is cleared (`close_autocmd_id = nil`) to avoid conflicts.
---@return nil
function M.remove_ui_autocmd()
  if close_autocmd_id then
    nvim_del_autocmd(close_autocmd_id)
    close_autocmd_id = nil
  end
end

return M
