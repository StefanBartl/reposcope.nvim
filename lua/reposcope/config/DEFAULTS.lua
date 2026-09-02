---@module 'reposcope.config.DEFAULTS'
---@brief Default values for all `ConfigOptions`, merged with user options in `setup()`.

-- ENV-VAR Utility
local env_get = require("reposcope.utils.env").get

---@type ConfigOptions
local defaults = {
  prompt_fields = { "prefix", "keywords", "owner", "language" }, -- Default fields for the prompt in the UI
  provider = "github", -- Default provider for Reposcope (GitHub)
  preferred_requesters = { "gh", "curl", "wget" }, -- Preferred tools for API requests
  request_tool = "gh", -- Default request tool (GitHub CLI)
  github_token = env_get("GITHUB_TOKEN") or "", -- Github authorization token (for higher request limits)
  gitlab_token = env_get("GITLAB_TOKEN") or "", -- GitLab authorization token (for higher request limits)
  codeberg_token = env_get("CODEBERG_TOKEN") or "", -- Codeberg authorization token (for higher request limits)
  results_limit = 25, -- Default result limit for search queries
  layout = "default", -- Default UI layout
  clone = {
    std_dir = env_get("REPOS_DIR") or "~/temp", -- Standard path for cloning repositories (defaults to $REPOS_DIR, if set)
    type = "", -- Tool for cloning repositories (choose curl' or 'wget' for .zip repositories. 'gh' is possible. Default is 'git'.)
  },
  -- Register a hover.nvim source, so resting the cursor on `owner/repo`
  -- anywhere -- a plugin spec, a lockfile, a note -- previews that
  -- repository's cached README. Answers only for repositories reposcope has
  -- already fetched, never for arbitrary slug-shaped text. A no-op without
  -- hover.nvim installed. See docs/hover.md.
  hover = true,
  keymaps = {
    open = "<leader>rs", -- Set the keymap to open Repsocope
    close = "<leader>rc", -- Set the keymap to close Reposcope
  },
  keymap_opts = {
    silent = true, -- Silent option for open and close keymap
    noremap = true, -- noremap option for open and close keymap
  },
  prompt_keymaps = {
    confirm = "<CR>", -- Confirm prompt input
    nav_up = "<Up>", -- Navigate list up
    nav_down = "<Down>", -- Navigate list down
    focus_next = { "<C-w>", "<C-l>", "<Tab>" }, -- Focus next prompt field
    focus_prev = { "<C-h>", "<S-Tab>" }, -- Focus previous prompt field
    open_viewer = "<C-v>", -- Open README viewer
    open_editor = "<C-b>", -- Open README editor
    clone = "<C-c>", -- Clone selected repository
    backspace = "<BS>", -- Backspace (disabled at column 0, line 2)
    preview_scroll_down = "<C-d>", -- Scroll the README preview down (stays focused in the prompt)
    preview_scroll_up = "<C-u>", -- Scroll the README preview up (stays focused in the prompt)
    preview_image = "<C-p>", -- Draw the README's image over the preview; needs images.nvim with `display.remote.enabled = true`
    help = "?", -- Show the keymap cheatsheet (normal mode only, so "?" still types in insert mode)
    toggle_favorite = "<C-f>", -- Toggle favorite for the currently selected repository
  }, -- Set an action to `false` or `""` to disable it
  prompt_prefix_symbol = " " .. "\u{f002}" .. " ", -- Symbol shown in the `prefix` field; needs a Nerd Font. Set e.g. "> " for plain terminals

  -- Only change the following values in your setup({}) if you fully understand the impact; incorrect values may cause incomplete data or plugin crashes.
  metrics = false,
  log_max = 1000, -- Controls the size of the log file
  progress_style = "auto", -- Indicator for `:Reposcope update`/`status` over many repositories; needs lib.nvim, no-op without it
  readme_precache_count = 5, -- After a search, pre-cache READMEs for this many top results (0 disables) so scrolling feels instant
}

return defaults
