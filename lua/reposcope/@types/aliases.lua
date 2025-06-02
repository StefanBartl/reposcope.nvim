---@module 'reposcope.@types.aliases'
---@brief Global type aliases for Reposcope
---@description
--- This module defines shared alias types used throughout Reposcope for
--- configuration keys, prompt field labels, request tools, and layout types.
--- These aliases improve annotation consistency and LuaLS type inference.

---@alias Buffer integer|nil
---@alias Window integer|nil

--- === config ===
---@alias ConfigOptionKey "provider" | "preferred_requesters" | "request_tool" | "github_token" | "results_limit" | "layout" | "clone" | "keymaps" | "keymap_opts" | "metrics" | "cache_dir" | "logfile_path" | "log_max"
---@alias PromptField "prefix" | "keywords" | "owner" | "language" | "topic" | "stars"
---@alias RequestTool "gh" | "curl" | "wget"
---@alias LayoutType "default" | "horizontal" | "vertical" | "float" | ""

--- === providers/github ====
---@alias Query string


--- === utils ===
---@alias RequestMetricsData { successful: number, failed: number, cache_hitted: number, fcache_hitted: number }
---@alias UUID string A string in the format XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX (hexadecimal UUID)

