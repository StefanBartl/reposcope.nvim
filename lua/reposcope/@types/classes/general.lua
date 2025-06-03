---@module 'reposcope.@types.classes.general'
---@brief General-purpose class definitions used across Reposcope
---@description
--- This module defines shared class structures for modules that do not have
--- dedicated type or class definition files. It is primarily intended for
--- lightweight functional modules that don't warrant their own types file.
--- All general-purpose or fallback class annotations should be placed here
--- to ensure consistent typing throughout the project.

---@class UIInitModule Functions to start and close the Reposcope UI
---@field setup fun(opts: table|nil): nil Initializes the UI and performs prechecks
---@field open_ui fun(): nil Opens the Reposcope UI: Captures caller position, calls the window factory functions and sets keymaps
---@field close_ui fun(): nil Closes the Reposcope UI: Set focus back to caller position, close all windows and unset keymaps
---@field setup_ui_close fun(): nil Sets up an AutoCmd for automatically closing all related UI windows (Reposcope UI)
---@field remove_ui_autocmd fun(): nil Removes the AutoCmd for automatically closing all related UI windows (Reposcope UI)

---@class UIKeymapsModule
---@field set_ui_keymaps fun(): nil Applies all UI-related keymaps
---@field unset_ui_keymaps fun(): nil Removes all UI-related keymaps
---@field set_prompt_keymaps fun(): nil Applies all prompt-related keymaps
---@field unset_prompt_keymaps fun(): nil Removes all prompt-related keymaps
---@field set_clone_keymaps fun(): nil Applies all clone-related keymaps
---@field unset_clone_keymaps fun(): nil Removes all clone-related keymaps
---@field set_user_keymaps fun(map_cfg?: table, opts?: table): nil Sets user keymaps for opening/closing Reposcope

---@class ReposcopeHealthModule
---@field check fun(): nil Performs a health check for reposcope.nvim environment

