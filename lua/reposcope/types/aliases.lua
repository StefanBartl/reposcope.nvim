---@module 'reposcope.types.aliases'
---@brief Shared type aliases for configuration and UI parameters
---@description
--- This module defines global alias types used across Reposcope such as prompt
--- field identifiers and valid request tool names. These aliases are used for
--- annotation consistency and LuaLS type inference.

-- All keys in the reposcope/config.lua options table
---@alias ConfigOptionKey
---| "provider"
---| "preferred_requesters"
---| "request_tool"
---| "github_token"
---| "results_limit"
---| "preview_limit"
---| "layout"
---| "clone"
---| "keymaps"
---| "keymap_opts"
---| "metrics"
---| "cache_dir"
---| "log_filepath"
---| "log_max"

-- Prompt field types (used to build prompt UI dynamically)
---@alias PromptField "prefix" | "keywords" | "owner" | "language" | "topic" | "stars"

-- Request tool identifiers (used in config/options)
---@alias RequestTool "gh" | "curl" | "wget"


-- Future enums could include:
-- @alias LayoutType "horizontal" | "vertical"
-- @alias ListSort "stars" | "updated" | "name"

return {}
