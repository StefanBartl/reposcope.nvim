---@module 'reposcope.@types.aliases'
---@brief Global type aliases for Reposcope

---@alias ListValueTypes "string" | "number" | "boolean" | "table" | "any"

---@alias ErrorType
---| "UnexpectedError"
---| "InvalidStateError"
---| "InvalidQueryError"
---| "NetworkError"
---| "FileReadError"
---| "JsonDecodeError"

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

---@alias PromptField # The field key (e.g. "keywords", "owner") REF: CHECK if this is lsp ok
---| "prefix"
---| "keywords"
---| "owner"
---| "language"
---| "topic"
---| "stars"

---@class PromptBufferMap
---@field prefix Buffer
---@field keywords Buffer
---@field owner Buffer
---@field language Buffer
---@field topic Buffer
---@field stars Buffer

---@alias RequestToolName
---| "gh"
---| "curl"
---| "wget"

---@alias LayoutType
---| "default"
---| "horizontal"
---| "vertical"
---| "float"
---| ""

---@alias Buffer integer|nil
---@alias Window integer|nil

---@alias Query string # A query attached from prompt input fields and build to request provider --REF:

---@alias RequestMetricsData { successful: number, failed: number, cache_hitted: number, fcache_hitted: number }
---@alias UUID string A string in the format XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX (hexadecimal UUID)

---@alias ReadmeURLs { raw: string, api: string }

---@alias PromptInput string # The user-entered value

---@alias RepositoryApiResult { total_count: number, items: Repository[] }

