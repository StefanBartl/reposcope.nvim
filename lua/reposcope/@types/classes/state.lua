---@module 'reposcope.@types.classes.state'
---@brief Shared class definitions for UI, request, and popup state

---@class PopupsStateManagerModule
---@field stats StatsPopupState State for buffer and window for the stats popup

---@class StatsPopupState
---@field buf Buffer Buffer of the stats popup
---@field win Window of the stats popup

---@class PromptStateManagerModule
---@field set_field_text fun(field: string, text: string): nil Sets the current input text for a given prompt field
---@field get_field_text fun(field: string): string Retrieves the input text for a given prompt field

---@class PromptInputMap
---@field [PromptField] string?

---@class UIStateManagerModule
---@field invocation UIStateInvocation Invocation editor state before UI activation
---@field capture_invocation_state fun(): nil Captures the current window and cursor position for later restoration
---@field get_invocation_win fun(): number|nil Returns the window ID of the invocation state
---@field get_invocation_cursor fun(): UIStateCursor Returns the cursor position of the invocation state
---@field reset fun(tbl?: "buffers"|"windows"|"invocation"): nil Resets part or all of the UI state (default: all)
---
-- Buffers and windows
---@field buffers UIStateBuffers Buffer handles by role
---@field windows UIStateWindows Window handles by role
---@field get_buffers fun(): number[]|nil Returns all active buffer handles (if any)
---@field get_valid_buffer fun(buf_name: string): number|nil Returns the buffer number if valid and tracked
---@field get_windows fun(): number[]|nil Returns all active window handles (if any)
---
-- List UI State
---@field list UIStateList List-specific UI state (e.g. selection)
---@field is_list_populated fun(): boolean Returns true if the list UI was populated at least once
---@field set_list_populated fun(val: boolean): nil Sets internal flag indicating list was populated

---@class UIStateInvocation
---@field win Window window ID before UI was opened
---@field cursor UIStateCursor cursor position before UI was opened

---@class UIStateCursor
---@field row integer|nil
---@field col integer|nil

---@class UIStateBuffers
---@field backg Buffer
---@field preview Buffer
---@field prompt PromptBufferMap|nil
---@field prompt_prefix Buffer
---@field list Buffer
---@field readme_viewer Buffer

---@class UIStateWindows
---@field backg Window
---@field preview Window
---@field prompt table|nil
---@field prompt_prefix Window
---@field list Window
---@field readme_viewer Window

---@class UIStateList
---@field last_selected_line integer|nil The last selected line number in the list

---@class RequestStateManagerModule
---@field register_request fun(uuid: string): nil Registers a new UUID in an inactive state
---@field start_request fun(uuid: string): nil Marks a registered UUID as active
---@field end_request fun(uuid: string): nil Marks a UUID request as completed
---@field is_registered fun(uuid: string): boolean Returns true if the UUID was registered
---@field is_request_active fun(uuid: string): boolean Returns true if UUID is active
---@field clear_all_requests fun(): nil Clears all tracked UUID requests
