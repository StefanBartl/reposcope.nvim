require("reposcope.types.aliases")

---@class ReposcopeDefaultOptions
---@field prompt_fields PromptField[] Default fields for the prompt UI
---@field provider string The API provider to be used (default: "github")
---@field preferred_requesters string[] List of preferred tools for making HTTP requests (default: {"gh", "curl", "wget"})
---@field request_tool RequestTool Default request tool (default: "gh")
---@field github_token string  Github authorization token (for higher request limits)
---@field results_limit number Maximum number of results returned in search queries (default: 25)
---@field preview_limit number Maximum number of lines shown in preview (default: 200)
---@field layout string UI layout type (default: "default")
---@field keymaps table<string, string> Set keymaps to open and close Reposcope
---@field keymap_opts table Set keymap options
---@field metrics boolean Controls the state to record metrics
---@field cache_dir string Path for Reposcope cache data (default: OS-dependent) 
---@field log_filepath string Full path to the log file (determined dynamically)
---@field log_max number Controls the size of the log file
local M = {}

M.options = {
  ---@type PromptField[]
  prompt_fields = { "prefix", "keywords", "owner", "language" }, -- Default fields for the prompt in the UI
  provider = "github", -- Default provider for Reposcope (GitHub)
  preferred_requesters = { "gh", "curl", "wget" }, -- Preferred tools for API requests
  request_tool = "gh", -- Default request tool (GitHub CLI)
  github_token = "", -- Github authorization token (for higher request limits)
  results_limit = 25, -- Default result limit for search queries
  preview_limit = 200, -- Default preview limit for displayed results
  layout = "default", -- Default UI layout
  clone = {
    std_dir = "~/temp",  -- Standard path for cloning repositories
    type = "", -- Tool for cloning repositories (choose 'curl' or 'wget' for .zip repositories)
  },
  keymaps = {
    open = "<leader>rs",  -- Set the keymap to open Repsocope
    close = "<leader>rc",  -- Set the keymap to close Reposcope
  },
  keymap_opts = {
    silent = true,  -- Silent option for open and close keymap
    noremap = true,  -- noremap option for open and close keymap
  },


  -- Only change the following values in your setup({}) if you fully understand the impact; incorrect values may cause incomplete data or plugin crashes.
  metrics = false,
  cache_dir = "", -- Cache path for persistent cache files; standard is: vim.fn.stdpath("cache") .. "/reposcope/data"
  log_filepath = "", -- Full path (without .ext) to the log file; standard is: vim.fn.stdpath("cache") .. "/reposcope/logs/log"
  log_max = 1000, -- Controls the size of the log file
}

return M
