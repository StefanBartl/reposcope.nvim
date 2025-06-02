---@module 'reposcope.defaults'
---@brief Provides the default configuration options for Reposcope.
---@description
--- This module defines the fallback values used by Reposcope when no user configuration
--- is provided or only partial configuration is given. It returns a `ConfigOptions` table
--- with all required fields, and serves as the base layer in the setup resolution cascade:
---
--- 1. `reposcope.defaults.options` — project-wide safe defaults
--- 2. `config.lua`                — optional plugin-local overrides
--- 3. `setup({ ... })`           — user-provided values in init.lua
---
--- This module should **not** be modified directly unless you're changing plugin defaults.

---@class ReposcopeDefaultConfig : ReposcopeConfig
local M = {}

---@type ConfigOptions
M.options = {
  prompt_fields = { "prefix", "keywords", "owner", "language" }, -- Default fields for the prompt in the UI
  provider = "github", -- Default provider for Reposcope (GitHub)
  preferred_requesters = { "gh", "curl", "wget" }, -- Preferred tools for API requests
  request_tool = "gh", -- Default request tool (GitHub CLI)
  github_token = "", -- Github authorization token (for higher request limits)
  results_limit = 25, -- Default result limit for search queries
  layout = "float", -- Default UI layout
  clone = {
    std_dir = "~/temp",  -- Standard path for cloning repositories
    type = "", -- Tool for cloning repositories (choose curl' or 'wget' for .zip repositories. 'gh' is possible. Default is 'git'.)
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
  log_max = 1000, -- Controls the size of the log file
}

return M
