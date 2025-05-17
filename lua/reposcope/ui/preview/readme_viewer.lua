--- @class UIShowReadme
--- @field show fun(): nil Displays the README of the selected repository in either a fullscreen buffer (Markdown) or a browser (HTML)
local M = {}

local debug = require("reposcope.utils.debug")
local cache = require("reposcope.state.readme")
local ui_state = require("reposcope.state.ui")
local repositories = require("reposcope.state.repositories")
local os = require("reposcope.utils.os")

--- Displays the README of the currently selected repository.
--- If the README contains HTML content, it opens in the default web browser.
--- If the README is Markdown, it opens in a fullscreen Neovim buffer.
function M.show()

-- Get content for the readme viewer
  -- Retrieve the currently selected repository
  local repo = repositories.get_selected_repo()
  if not repo then
    debug.notify("[reposcope] No selected repository available", 4)
    return
  end

  local repo_name = repo.name

  -- Try to load the README from the in-memory cache
  local content = cache.get_cached_readme(repo_name)
  if not content then
    debug.notify("[reposcope] README not cached for: " .. repo_name, 4)
  end

  -- Try to load the README from the file cache (persistent)
  content = cache.get_fcached_readme(repo_name)
  if not content then
    debug.notify("[reposcope] README not filecached for: " .. repo_name, 4)
    content = "README not cached yet."
  end

-- Check if the README content contains HTML tags (indicative of an HTML README). If so, try open browser
  if
    content:match("<html>") or
    content:match("<head>") or
    content:match("<body>") or
    content:match("<img src") or
    content:match("<!--") or
    content:match("<div>") or
    content:match("<h1") or
    content:match("<a href=")
  then
    -- If HTML is detected, open the repository page in the default browser
    local url = "https://github.com/" ..repo.owner.login .. "/" .. repo_name
    os.open_url(url)
    return
  end

-- Display the README in a fullscreen Neovim buffer
  -- Reuse README buffer if exists
  local buf
  if ui_state.buffers.readme_viewer and vim.api.nvim_buf_is_valid(ui_state.buffers.readme_viewer) then
    buf = ui_state.buffers.readme_viewer
    vim.bo[buf].modifiable = true
    debug.notify("[reposcope] Using existing README buffer", 2)
  else
    buf = require("reposcope.utils.protection").create_named_buffer("reposcope://readme_viewer")
    ui_state.buffers.readme_viewer = buf
    debug.notify("[reposcope] Created new README buffer", 2)
    print("number", buf)
  end

  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    debug.notify("[reposcope] Cannot create valid buffer for readme_viewer", 4)
    return
  end

  -- Write content in the buffer
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true

  -- Close existing README Viewer windows, if open
  if ui_state.windows.readme_viewer and vim.api.nvim_win_is_valid(ui_state.windows.readme_viewer) then
    vim.api.nvim_win_close(ui_state.windows.readme_viewer, true)
    debug.notify("[reposcope] Closed existing README window", 2)
  end

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = vim.o.columns,
    height = vim.o.lines - 3,
    col = 0,
    row = 0,
    style = "minimal",
    border = "none",
  })

  ui_state.windows.readme_viewer = win
  vim.api.nvim_set_current_win(win)

  M.set_viewer_keymap(buf)

  vim.cmd("stopinsert")
  vim.cmd("normal! gg")
end


function M.close()
  if ui_state.windows.readme_viewer and vim.api.nvim_win_is_valid(ui_state.windows.readme_viewer) then
    vim.api.nvim_win_close(ui_state.windows.readme_viewer, true)
    debug.notify("[reposcope] README window closed", 2)
  end

  ui_state.windows.readme_viewer = nil

  print("close")
end

function M.set_viewer_keymap(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    debug.notify("[reposcope] Unable to set keymap, buffer is invalid", 3)
    return
  end

  -- Keymap für "q" im README-Viewer setzen
  vim.api.nvim_buf_set_keymap(buf, "n", "q", ":lua require'reposcope.ui.preview.readme_viewer'.close()<CR>", {
    noremap = true,
    silent = true,
    nowait = true
  })
  debug.notify("[reposcope] Keymap 'q' set for README viewer", 2)
  print("[reposcope] Keymap 'q' for quit README viewer", 2)
end

return M
