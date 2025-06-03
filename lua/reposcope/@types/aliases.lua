---@module 'reposcope.@types.aliases'
---@brief Global type aliases for Reposcope

---@alias Buffer integer|nil
---@alias Window integer|nil


---@alias ConfigOptionKey
---| "provider"
---| "preferred_requesters"
---| "request_tool"
---| "github_token"
---| "results_limit"
---| "layout"
---| "clone"
---| "keymaps"
---| "keymap_opts"
---| "metrics"
---| "cache_dir"
---| "logfile_path"
---| "log_max"

---@alias PromptField
---| "prefix"
---| "keywords"
---| "owner"
---| "language"
---| "topic"
---| "stars"

---@alias RequestTool
---| "gh"
---| "curl"
---| "wget"

---@alias LayoutType
---| "default"
---| "horizontal"
---| "vertical"
---| "float"
---| ""


---@alias Query string


---@alias RequestMetricsData { successful: number, failed: number, cache_hitted: number, fcache_hitted: number }
---@alias UUID string A string in the format XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX (hexadecimal UUID)


---@alias ReadmeURLs { raw: string, api: string }
