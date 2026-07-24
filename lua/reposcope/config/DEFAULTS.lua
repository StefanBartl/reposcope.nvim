---@module 'reposcope.config.DEFAULTS'
---@brief Default values for all `ConfigOptions`, merged with user options in `setup()`.

-- ENV-VAR Utility
local env_get = require("reposcope.utils.env").get

---@type ConfigOptions
local defaults = {
  prompt_fields = { "prefix", "keywords", "owner", "language" }, -- Default fields for the prompt in the UI
  provider = "github",                                           -- Default provider for Reposcope (GitHub)
  preferred_requesters = { "gh", "curl", "wget" },               -- Preferred tools for API requests
  request_tool = "gh",                                           -- Default request tool (GitHub CLI)
  github_token = env_get("GITHUB_TOKEN") or "",                  -- Github authorization token (for higher request limits)
  gitlab_token = env_get("GITLAB_TOKEN") or "",                  -- GitLab authorization token (for higher request limits)
  codeberg_token = env_get("CODEBERG_TOKEN") or "",               -- Codeberg authorization token (for higher request limits)
  results_limit = 25,                                            -- Default result limit for search queries
  layout = "default",                                            -- Default UI layout
  clone = {
    std_dir = "~/temp",                                          -- Standard path for cloning repositories
    type = "",                                                   -- Tool for cloning repositories (choose curl' or 'wget' for .zip repositories. 'gh' is possible. Default is 'git'.)
  },
  keymaps = {
    open = "<leader>rs",  -- Set the keymap to open Repsocope
    close = "<leader>rc", -- Set the keymap to close Reposcope
  },
  keymap_opts = {
    silent = true,  -- Silent option for open and close keymap
    noremap = true, -- noremap option for open and close keymap
  },
  prompt_keymaps = {
    confirm     = "<CR>",                         -- Confirm prompt input
    nav_up      = "<Up>",                         -- Navigate list up
    nav_down    = "<Down>",                       -- Navigate list down
    focus_next  = { "<C-w>", "<C-l>", "<Tab>" },  -- Focus next prompt field
    focus_prev  = { "<C-h>", "<S-Tab>" },         -- Focus previous prompt field
    open_viewer = "<C-v>",                        -- Open README viewer
    open_editor = "<C-b>",                        -- Open README editor
    clone       = "<C-c>",                        -- Clone selected repository
    backspace   = "<BS>",                         -- Backspace (disabled at column 0, line 2)
  },                                               -- Set an action to `false` or `""` to disable it

  -- Only change the following values in your setup({}) if you fully understand the impact; incorrect values may cause incomplete data or plugin crashes.
  metrics = false,
  log_max = 1000, -- Controls the size of the log file
}

return defaults
