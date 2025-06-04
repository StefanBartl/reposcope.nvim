---@module 'reposcope.types.configs'
---@brief Type definitions for user configuration

---@class CloneOptions
---@brief Repository clone settings
---@field std_dir string Directory to clone repositories into
---@field type string Tool used for cloning (e.g. 'curl', 'wget')

---@class ConfigOptions
---@brief All configurable options accepted by `reposcope.setup()`
---@field prompt_fields PromptField[] Default fields shown in the prompt UI
---@field provider string API provider used for search requests (e.g. "github")
---@field preferred_requesters string[] Fallback order of CLI tools to use for HTTP requests
---@field request_tool string Main tool to perform HTTP requests (used unless unavailable)
---@field github_token? string Optional GitHub token for authenticated API calls
---@field results_limit number Maximum number of search results to show
---@field layout LayoutType Default layout for result view
---@field clone CloneOptions Options related to downloading/cloning repositories
---@field keymaps table<string, string> Custom key mappings for plugin actions
---@field keymap_opts table Options passed to all keymaps (e.g. `noremap`, `silent`)
---@field metrics boolean Enable or disable anonymous usage metrics
---@field log_max number Maximum log size (lines)

---@class ReposcopeConfigModule
---@brief Structure exposed to the outside and used during `setup()`
---@field options ConfigOptions Full configuration options
---@field setup fun(opts: table): nil Setup function to initialize the plugin
---@field get_option fun(key: ConfigOptionKey): any Retrieve a value from config.options

--- Type to be able to pass the opts table to the setup function
---@class PartialConfigOptions
---@field prompt_fields? PromptField[]
---@field provider? string
---@field preferred_requesters? string[]
---@field request_tool? string
---@field github_token? string
---@field results_limit? number
---@field layout? LayoutType
---@field clone? CloneOptions
---@field keymaps? table<string, string>
---@field keymap_opts? table
---@field metrics? boolean
---@field log_max? number

