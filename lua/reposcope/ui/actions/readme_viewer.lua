---@module 'reposcope.ui.actions.readme_viewer'
---@class ActionOpenReadmeViewer
---@brief Opens and displays a cached README in a dedicated temporary viewer
---@description
--- This module provides functionality to display a cached README either in a fullscreen
--- Markdown buffer or, if the content is HTML, in the system browser. It handles buffer
--- reuse, window creation, filetype setup, and viewer-specific keymaps.
---
--- This viewer is designed for temporary, read-only inspection of repository READMEs.
---@field open_viewer fun(): nil Displays the README of the selected repository in either a fullscreen buffer (Markdown) or a browser (HTML)
---@field close_viewer fun(): nil Closes the README viewer window if open
---@field set_viewer_keymap fun(buf: integer): nil Sets keymaps for the viewer buffer (e.g., 'q' to close')
local M = {}

---Forward declarations for private functions
local is_html_content, open_in_browser, prepare_readme_buffer, open_readme_window

-- Debugging Utility
local notify = require("reposcope.utils.debug").notify
-- Caching (Readme Cache Management)
local readme_cache = require("reposcope.cache.readme_cache")
-- State Management (UI State, Repositories State)
local ui_state = require("reposcope.state.ui.ui_state")
-- Cache Management
local repository_cache = require("reposcope.cache.repository_cache")
-- OS Utilities (Operating System Commands)
local os = require("reposcope.utils.os")


--- Opens the viewer for the selected repository's README
--- Displays HTML in a browser or Markdown in a temporary Neovim buffer
---@return nil
function M.open_viewer()
  local repo = repository_cache.get_selected()
  if not repo or not repo.name then
    notify("[reposcope] No repository selected or invalid.", 3)
    return
  end

  local content = readme_cache.get_readme(repo.name)
  if not content then return end

  if is_html_content(content) then
    open_in_browser(repo)
    return
  end

  local buf = prepare_readme_buffer(content)
  if not buf then return end

  open_readme_window(buf)
end


---@private
--- Detects whether a README content string contains HTML-like content
---@param content string The content to test
---@return boolean True if content appears to be HTML
function is_html_content(content)
  return content:match("<html>") or content:match("<head>") or content:match("<body>") or content:match("<div>")
end


---@private
--- Opens the repository's GitHub page in the system browser
---@param repo table The repository table (must contain `.owner.login` and `.name`)
---@return nil
function open_in_browser(repo)
  local url = "https://github.com/" .. repo.owner.login .. "/" .. repo.name
  os.open_url(url)
  notify("[reposcope] Opened in browser: " .. url, 2)
end


---@private
--- Prepares and fills the README buffer with the provided Markdown content
---@param content string The README text to display
---@return integer|nil The buffer handle, or nil if creation failed
function prepare_readme_buffer(content)
  local buf = ui_state.buffers.readme_viewer
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    buf = require("reposcope.utils.protection").create_named_buffer("reposcope://readme_viewer")
    ui_state.buffers.readme_viewer = buf
    notify("[reposcope] Created new README buffer", 2)
  else
    vim.bo[buf].modifiable = true
    notify("[reposcope] Using existing README buffer", 2)
  end

  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    notify("[reposcope] Cannot create valid buffer for readme_viewer", 4)
    return nil
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buftype = "nofile"
  vim.api.nvim_buf_set_name(buf, "reposcope://README.md")
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
function open_readme_window(buf)
  local old_win = ui_state.windows.readme_viewer
  if old_win and vim.api.nvim_win_is_valid(old_win) then
    vim.api.nvim_win_close(old_win, true)
    notify("[reposcope] Closed existing README window", 2)
  end

  local win = vim.api.nvim_open_win(buf, true, {
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

  require("reposcope.ui.prompt.prompt_autocmds").cleanup_autocmds()
  require("reposcope.keymaps").unset_prompt_keymaps()
  M.set_viewer_keymap(buf)

  vim.cmd("stopinsert")
  vim.cmd("normal! gg")
end

--- Closes the README viewer window and buffer
---@return nil
function M.close_viewer()
  local buf = ui_state.buffers.readme_viewer
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end

  ui_state.buffers.readme_viewer = nil
  require("reposcope.ui.prompt.prompt_autocmds").setup_autocmds()
  require("reposcope.keymaps").set_prompt_keymaps()
end

--- Sets viewer-specific keymaps for a given buffer (e.g., 'q' to close viewer)
---@param buf integer The buffer handle
---@return nil
function M.set_viewer_keymap(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    notify("[reposcope] Unable to set keymap, buffer is invalid", 3)
    return
  end

  vim.api.nvim_buf_set_keymap(buf, "n", "q", ":lua require'reposcope.ui.actions.readme_viewer'.close_viewer()<CR>", {
    noremap = true,
    silent = true,
    nowait = true,
  })

  notify("[reposcope] Keymap 'q' set for quitting README viewer", 2)
end

return M
