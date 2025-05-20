---@class ActionOpenReadmeViewer
---@brief Opens the README in a temporary viewer window
---@description
--- This action opens the cached README in a temporary, non-editable, closable window.
--- It is triggered via keymap and is intended for one-time viewing only.
---@field open_viewer fun(): nil Displays the README of the selected repository in either a fullscreen buffer (Markdown) or a browser (HTML)
---@field close_viewer fun(): nil Closes the README viewer window if open
---@field set_viewer_keymap fun(buf: integer): nil Sets keymaps for the viewer buffer (e.g., 'q' to close)
local M = {}

-- Debugging Utility
local notify = require("reposcope.utils.debug").notify
-- Caching (Readme Cache Management)
local readme_cache = require("reposcope.cache.readme_cache")
-- State Management (UI State, Repositories State)
local ui_state = require("reposcope.state.ui.ui_state")
local repositories_state = require("reposcope.state.repositories.repositories_state")
-- OS Utilities (Operating System Commands)
local os = require("reposcope.utils.os")


--- Displays the README of the currently selected repository.
--- If the README contains HTML content, it opens in the default web browser.
--- If the README is Markdown, it opens in a fullscreen Neovim buffer.
---@return nil
function M.open_viewer()
  local repo = repositories_state.get_selected_repo()
  if not repo or not repo.name then
    notify("[reposcope] No repository selected or invalid.", 3)
    return
  end

  local repo_name = repo.name

  -- Try RAM cache first
  local content = readme_cache.get_cached_readme(repo_name)
  if not content then
    notify("[reposcope] README not cached for: " .. repo_name, 4)
    -- Try file cache
    content = readme_cache.get_fcached_readme(repo_name)
    if not content then
      notify("[reposcope] README not filecached for: " .. repo_name, 4)
      content = "README not cached yet."
    end
  end

  -- Open in browser if HTML-like
  if content:match("<html>") or content:match("<head>") or content:match("<body>") or
     content:match("<img src") or content:match("<!--") or content:match("<div>") or
     content:match("<h1") or content:match("<a href=") then
    local url = "https://github.com/" .. repo.owner.login .. "/" .. repo_name
    os.open_url(url)
    return
  end

  -- Prepare buffer
  local buf
  if ui_state.buffers.readme_viewer and vim.api.nvim_buf_is_valid(ui_state.buffers.readme_viewer) then
    buf = ui_state.buffers.readme_viewer
    vim.bo[buf].modifiable = true
    notify("[reposcope] Using existing README buffer", 2)
  else
    buf = require("reposcope.utils.protection").create_named_buffer("reposcope://readme_viewer")
    ui_state.buffers.readme_viewer = buf
    notify("[reposcope] Created new README buffer", 2)
  end

  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    notify("[reposcope] Cannot create valid buffer for readme_viewer", 4)
    return
  end

  -- Write content in the buffer
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
  vim.bo[buf].bufhidden = "wipe"  -- TEST:
  vim.bo[buf].buftype = "nofile"  -- TEST:
  vim.api.nvim_buf_set_name(buf, "reposcope://README.md")
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].syntax = "markdown"

  vim.cmd("syntax enable")
  vim.cmd("setlocal syntax=markdown")
  vim.cmd("setlocal ft=markdown")

  if pcall(require, "nvim-treesitter") then
    vim.cmd("TSBufEnable highlight")
  end

  -- Close old window if open
  if ui_state.windows.readme_viewer and vim.api.nvim_win_is_valid(ui_state.windows.readme_viewer) then
    vim.api.nvim_win_close(ui_state.windows.readme_viewer, true)
    notify("[reposcope] Closed existing README window", 2)
  end

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = vim.o.columns,
    height = vim.o.lines - 3,
    col = 0,
    row = 0,
    style = "minimal",
    border = "single",
    focusable = true,
    title = "README VIEWER",  -- TEST:
    title_pos = 'center',     -- TEST:
  })

  ui_state.windows.readme_viewer = win
  vim.api.nvim_set_current_win(win)

  M.set_viewer_keymap(buf)

  vim.cmd("stopinsert")
  vim.cmd("normal! gg")
end


---Closes the README viewer window.
---@return nil
function M.close_viewer()
  if ui_state.windows.readme_viewer and vim.api.nvim_win_is_valid(ui_state.windows.readme_viewer) then
    vim.api.nvim_win_close(ui_state.windows.readme_viewer, true)
  end
  ui_state.windows.readme_viewer = nil
end


---Sets keymaps for the viewer buffer (e.g., 'q' to close).
---@param buf integer The buffer handle to apply the keymap to
---@return nil
function M.set_viewer_keymap(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    notify("[reposcope] Unable to set keymap, buffer is invalid", 3)
    return
  end

  vim.api.nvim_buf_set_keymap(buf, "n", "q", ":lua require'reposcope.ui.actions.readme_viewer'.close_viewer()<CR>", {
    noremap = true,
    silent = true,
    nowait = true
  })
  notify("[reposcope] Keymap 'q' set for quitting README viewer", 2)
end

return M
