---@module 'reposcope.types.aliases'
---@brief Global type aliases for Reposcope
---@description
--- This module defines shared alias types used throughout Reposcope for
--- configuration keys, prompt field labels, request tools, and layout types.
--- These aliases improve annotation consistency and LuaLS type inference.

---@alias ConfigOptionKey
---| "provider" | "preferred_requesters" | "request_tool"
---| "github_token" | "results_limit" | "preview_limit"
---| "layout" | "clone" | "keymaps" | "keymap_opts"
---| "metrics" | "cache_dir" | "logfile_path" | "log_max"

---@alias PromptField
--- Valid prompt fields shown in the interactive UI
---| "prefix" | "keywords" | "owner" | "language" | "topic" | "stars"

---@alias RequestTool
--- Supported CLI tools for making API requests
---| "gh" | "curl" | "wget"

---@alias LayoutType
--- Terminal layout type used in UI settings or terminal modules
---| "horizontal" | "vertical" | "float" | ""
