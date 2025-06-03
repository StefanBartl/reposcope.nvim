---@module 'reposcope.ui.actions.readme_viewer'
---@brief Opens and displays a cached README in a dedicated temporary viewer
---@description
--- This module provides functionality to display a cached README either in a fullscreen
--- Markdown buffer or, if the content is HTML, in the system browser. It handles buffer
--- reuse, window creation, filetype setup, and viewer-specific keymaps.
---
--- This viewer is designed for temporary, read-only inspection of repository READMEs.

---@class ActionOpenReadmeViewer : ActionOpenReadmeViewerModule
local M = {}

-- Vim Utilities
local api = vim.api
local nvim_buf_is_valid = api.nvim_buf_is_valid
local nvim_buf_delete = api.nvim_buf_delete
local set_km = api.nvim_buf_set_keymap
local nvim_buf_set_lines = api.nvim_buf_set_lines
local nvim_buf_set_name = api.nvim_buf_set_name
local nvim_win_is_valid = api.nvim_win_is_valid
local nvim_win_close = api.nvim_win_close
local nvim_open_win = api.nvim_open_win
-- Debugging Utility
local notify = require("reposcope.utils.debug").notify
-- Cache Management
local readme_cache_get = require("reposcope.cache.readme_cache").get
local repo_cache_get_selected = require("reposcope.cache.repository_cache").get_selected
-- State Management (UI State, Repositories State)
local ui_state = require("reposcope.state.ui.ui_state")
-- OS Utilities (Operating System Commands)
local os_open_url = require("reposcope.utils.os").open_url
-- Reposcope dependencies
local setup_autocmds = require("reposcope.ui.prompt.prompt_autocmds").setup_autocmds
local cleanup_autocmds = require("reposcope.ui.prompt.prompt_autocmds").cleanup_autocmds
local create_named_buffer = require("reposcope.utils.protection").create_named_buffer


---@private
--- Detects whether a README content string contains HTML-like content
---@param content string The content to test
---@return boolean True if content appears to be HTML
local function _is_html_content(content)
  return content:match("<html>") or content:match("<head>") or content:match("<body>") or content:match("<div>")
end


---@private
--- Opens the repository's GitHub page in the system browser
---@param repo table The repository table (must contain `.owner.login` and `.name`)
---@return nil
local function _open_in_browser(repo)
  local url = "https://github.com/" .. repo.owner.login .. "/" .. repo.name
  os_open_url(url)
  notify("[reposcope] Opened in browser: " .. url, 2)
end


---@private
--- Prepares and fills the README buffer with the provided Markdown content
---@param content string The README text to display
---@return integer|nil The buffer handle, or nil if creation failed
local function _prepare_readme_buffer(content)
  local buf = ui_state.buffers.readme_viewer
  if not buf or not nvim_buf_is_valid(buf) then
    buf = create_named_buffer("reposcope://readme_viewer")
    ui_state.buffers.readme_viewer = buf
    notify("[reposcope] Created new README buffer", 2)
  else
    vim.bo[buf].modifiable = true
    notify("[reposcope] Using existing README buffer", 2)
  end

  if not buf or not nvim_buf_is_valid(buf) then
    notify("[reposcope] Cannot create valid buffer for readme_viewer", 4)
    return nil
  end

  nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buftype = "nofile"
  nvim_buf_set_name(buf, "reposcope://README.md")
  vim.bo[buf].filetype = "markdown"

  if pcall(require, "nvim-treesitter") then
    vim.cmd("TSBufEnable highlight")
  end

  return buf
end


---@private
--- Opens a floating window to display the given README buffer
---@param buf integer The buffer handle to open in a window
---@return nil
local function _open_readme_window(buf)
  local old_win = ui_state.windows.readme_viewer
  if old_win and nvim_win_is_valid(old_win) then
    nvim_win_close(old_win, true)
    notify("[reposcope] Closed existing README window", 2)
  end

  local win = nvim_open_win(buf, true, {
    relative = "editor",
    width = vim.o.columns,
    height = vim.o.lines - 4,
    col = 0,
    row = 0,
    style = "minimal",
    border = "single",
    focusable = true,
    title = "README VIEWER",
    title_pos = "center",
  })

  vim.wo[win].wrap = true
  vim.wo[win].cursorline = true
  ui_state.windows.readme_viewer = win
  vim.api.nvim_set_current_win(win)

  cleanup_autocmds()
  require("reposcope.keymaps").unset_prompt_keymaps()
  M.set_viewer_keymap(buf)

  vim.cmd("stopinsert")
  vim.cmd("normal! gg")
end


--- Opens the viewer for the selected repository's README
--- Displays HTML in a browser or Markdown in a temporary Neovim buffer
---@return nil
function M.open_viewer()
  local repo = repo_cache_get_selected()
  if not repo or not repo.name then
    notify("[reposcope] No repository selected or invalid.", 3)
    return
  end

  local content = readme_cache_get(repo.name)
  if not content then return end

  if _is_html_content(content) then
    _open_in_browser(repo)
    return
  end

  local buf = _prepare_readme_buffer(content)
  if not buf then return end

  _open_readme_window(buf)
end


--- Closes the README viewer window and buffer
---@return nil
function M.close_viewer()
  local buf = ui_state.buffers.readme_viewer
  if buf and nvim_buf_is_valid(buf) then
    nvim_buf_delete(buf, { force = true })
  end

  ui_state.buffers.readme_viewer = nil
  setup_autocmds()
  require("reposcope.keymaps").set_prompt_keymaps()
end

--- Sets viewer-specific keymaps for a given buffer (e.g., 'q' to close viewer)
---@param buf integer The buffer handle
---@return nil
function M.set_viewer_keymap(buf)
  if not buf or not nvim_buf_is_valid(buf) then
    notify("[reposcope] Unable to set keymap, buffer is invalid", 3)
    return
  end

  set_km(buf, "n", "q", ":lua require'reposcope.ui.actions.readme_viewer'.close_viewer()<CR>", {
    noremap = true,
    silent = true,
    nowait = true,
  })

  notify("[reposcope] Keymap 'q' set for quitting README viewer", 2)
end

return M
