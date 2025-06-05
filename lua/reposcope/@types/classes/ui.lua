---@module 'reposcope.@types.classes.ui'
---@brief Shared class definitions for UI

---@class UIConfigurationModule
---@field width number Total width of UI
---@field height number Total height of UI
---@field col number Horizontal center of the UI
---@field row number Vertical center of the UI
---@field colortheme table<string, string> Color theme settings for the UI
---@field update_layout fun(width?: number, height?: number, col?: number, row?: number): nil Dynamically updates the UI layout settings
---@field update_theme fun(theme: string): nil Applies a pre-defined theme (e.g., "dark", "light")

---@class ActionCreateReadmeEditorModule
---@field open_editor fun(): nil Loads and buffers the README content in a detached bufferlocal M = {}

---@class ActionOpenReadmeViewerModule
---@field open_viewer fun(): nil Displays the README of the selected repository in either a fullscreen buffer (Markdown) or a browser (HTML)
---@field close_viewer fun(): nil Closes the README viewer window if open
---@field set_viewer_keymap fun(buf: integer): nil Sets keymaps for the viewer buffer (e.g., 'q' to close')

---@class BackgroundConfigModule
---@field row number The starting row position of the background window.
---@field col number The starting column position of the background window.
---@field width number The width of the background window.
---@field height number The height of the background window.
---@field border string The type of window border ("none", "single", "double").
---@field update_layout fun(row?: number, col?: number, width?: number, height?: number): nil Dynamically updates the background layout settings
---@field update_colors fun(bg: string):nil Dynamically updates the background colors

---@class BackgroundWindowModule
---@field open_window fun(): nil Opens the background window.
---@field close_window fun(): nil Closes the background window.

---@class ListUIModule
---@field initialize fun(): nil Creates the list window and displays cached repositories if available

---@class ListConfigModule
---@field width number The width of the list window
---@field height number The height of the list window
---@field row number The starting row position of the list window
---@field col number The starting column position of the list window
---@field highlight_color string The color for the selected list entry
---@field normal_color string The default text color for the list
---@field border string The type of window border ("none", "single", "double")
---@field update_layout fun(width?: number, height?: number, row?: number, col?: number): nil Dynamically updates the list layout settings -- LAYOUTS
---@field update_colors fun(highlight_color?: string, normal_color?: string): nil Dynamically updates the list colors --NIUY LAYOUTS
---@field update_border fun(border_layout: "none"|"single"|"double"): nil Dynamically updates the list border --NIUY LAYOUTS

---@class ListManagerModule
---@field set_and_display_list fun(entries: string[]): nil Sets the list entries and displays them
---@field update_list fun(lines: string[]): boolean Updates the list content and returns status
---@field clear_list fun(): nil Clears the list content
---@field get_selected fun(): string|nil Returns the currently selected list entry  --NUIY
---@field select_entry fun(index: number): nil Selects a specific list entry  --NUIY
---@field get_selected_entry fun(): string|nil Returns the currently selected list entry  --NUIY
---@field reset_selected_line fun(): nil Resets the last selected line and the line highlight

---@class ListWindowModule
---@field highlighted_line number Highlighted line index
---@field open_window fun(): boolean Opens list window, ensures the list window and buffer are created and initialized
---@field close_window fun(): nil Closes the list window
---@field configure fun(): nil Configures the list buffer with UI settings (no editing, restricted keymaps)
---@field apply_layout fun(): nil Applies layout and styling to the list window
---@field highlight_selected fun(index: number): nil Highlights the selected list entry
---@field set_highlighted_line fun(line: number): nil Sets the highlighted line in the list UI  --NIUY
---@field get_highlighted_entry fun(): string|nil Returns the currently highlighted list entry  --NIUY

---@class PreviewUIModule
---@field initialize fun(): nil Initializes the preview window and injects either the default banner or the last selected README.

---@class PreviewBannerModule
---@field get_banner fun(preview_width: number): string[] Function to dynamically generate a default, centered preview banner

---@class PreviewConfigModule
---@field width number Width of the preview window
---@field height number Height of the preview window
---@field row number Vertical position (top) of the window
---@field col number Horizontal position (left) of the window
---@field highlight_color string Highlighted text color
---@field normal_color string Default text color
---@field border string Border style of the window ("none", "single", "double")
---@field update_layout fun(width?: number, height?: number, row?: number, col?: number): nil Updates layout settings
---@field update_colors fun(highlight_color?: string, normal_color?: string): nil Updates highlight and text color
---@field update_border fun(border_layout: "none"|"single"|"double"): nil Updates the border type

---@class PreviewManagerModule
---@field update_preview fun(repo_name: string): nil Updates the preview with the README of the given repository
---@field clear_preview fun(): nil Set preview window to a blank line
---@field inject_content fun(buf: integer, lines: string[], filetype: string): nil Injects arbitrary content into the given buffer with the specified filetype
---@field inject_banner fun(buf: integer): nil Injects the default banner into the buffer (vertically and horizontally centered)

---@class PreviewWindowModule
---@field open_window fun(): boolean Opens the preview window with layout and banner and returns true or false
---@field close_window fun(): nil Closes the preview window if open
---@field apply_layout fun(): nil Applies visual styling (highlight, background) to the preview window

---@class UIPromptModule
---@field initialize fun(): nil Initializes the prompt UI

---@class UIPromptAutocommandsModule
---@field get_active_prompt_field fun(): string|nil Helper to determine which prompt field is currently active
---@field setup_autocmds fun(): nil Autocommands for prompt behavior
---@field cleanup_autocmds fun(): nil Cleans the prompt autocommands

---@class UIPromptBuffersModule
---@field setup_buffers fun(): nil Creates and registers all supported prompt buffers into ui_state

---@class UIPromptConfigModule
---@field prefix string Icon/prefix displayed left of user input
---@field prefix_len integer Display width of prefix (used for window sizing)
---@field height integer Height of the prompt input window in lines
---@field set_fields fun(fields: PromptField[]): nil Sets the prompt fields with validation and normalization
---@field get_fields fun(): string[] Returns the active prompt fields (deduplicated and sorted)
---@field get_available_fields fun(): string[] Returns all valid prompt fields (whitelist)

---@class UIPromptFocusModule
---@field set_current_index fun(index: number): nil Sets the current prompt index
---@field focus_first_input fun(): nil Sets focus to the first interactive prompt input field and enters insert mode.
---@field focus_field_index fun(index: integer): nil Sets focus to the input field at the specified index (1-based), and positions the cursor at line 2.
---@field focus_field fun(field: string): nil Focuses a field by its name (e.g. "keywords") if it exists in the configured field list --NOTE: nuiy
---@field navigate fun(direction: "next"|"prev"): nil Navigates to the next or previous field in the list, wrapping around  --NOTE: niuy

---@class UIPromptInputModule
---@field collect fun(): table<string, string>
---@field on_enter fun(): nil

---@class UIPromptLayoutModule
---@field build_layout fun(): {name: string, buffer: integer, width: integer, col: integer}[] List of window layouts

---@class UIPromptNavigationModule
---@field navigate_list_in_prompt fun(direction: "up"|"down"): nil Allows navigation within the list directly from the prompt
---@field set_list_to fun(line: number): nil Sets the list's current linr to given line number

---@class UIPromptManagerModule
---@field open_windows fun(): nil Initializes and renders the prompt UI
---@field close_windows fun(): nil Closes all prompt-related windows  --NOTE:  niuy
