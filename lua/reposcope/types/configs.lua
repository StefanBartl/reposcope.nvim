---@module 'reposcope.types.configs'
---@brief 
---@description
---

---@class ReposcopeConfig
---@field options ConfigOptions Configuration options for Reposcope
---@field setup fun(opts: table): nil Setup function for user configuration
---@field get_option fun(key: ConfigOptionKey): any Returns a specific value from config.options, with optional fallback

---@class CloneOptions 
---@field std_dir string Standardth for cloning repositories
---@field type string Tool for cloning repositories (choose 'curl' or 'wget' for .zip repositories)

--- Configuration options for Reposcope
---@class ConfigOptions
---@field prompt_fields PromptField[] Default fields for the prompt UI
---@field provider string The API provider to be used (default: "github")
---@field preferred_requesters string[] List of preferred tools for making HTTP requests (default: {"gh", "curl", "wget"})
---@field request_tool string Default request tool (default: "gh")
---@field github_token string  Github authorization token (for higher request limits)
---@field results_limit number Maximum number of results returned in search queries (default: 25)
---@field preview_limit number Maximum number of lines shown in preview (default: 200)
---@field layout string UI layout type (default: "default")
---@field clone CloneOptions Options to configure cloning repositories
---@field keymaps table<string, string> Set keymaps to open and close Reposcope
---@field keymap_opts table Set keymap options
---@field metrics boolean Controls the state to record metrics
---@field log_max number Controls the size of the log file


return {}
