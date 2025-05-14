--- @class UIShowReadme
--- @field show fun(): nil Displays the README of the selected repository in either a fullscreen buffer (Markdown) or a browser (HTML)
local M = {}

local debug = require("reposcope.utils.debug")
local readme_state = require("reposcope.state.readme")
local repositories = require("reposcope.state.repositories")
local keymaps = require("reposcope.keymaps")
local os = require("reposcope.utils.os")

--REF:

--- Displays the README of the currently selected repository.
--- If the README contains HTML content, it opens in the default web browser.
--- If the README is Markdown, it opens in a fullscreen Neovim buffer.
function M.show()
  -- Retrieve the currently selected repository
  local repo = repositories.get_selected_repo()
  if not repo then
    debug.notify("[reposcope] No selected repository available", 4)
    return
  end

  local repo_name = repo.name

  -- Try to load the README from the in-memory cache
  local content = readme_state.get_cached_readme(repo_name)
  if not content then
    debug.notify("[reposcope] README not cached for: " .. repo_name, 4)
  end

  -- Try to load the README from the file cache (persistent)
  content = readme_state.get_fcached_readme(repo_name)
  if not content then
    debug.notify("[reposcope] README not filecached for: " .. repo_name, 4)
    content = "README not cached yet."
  end

  -- Check if the README content contains HTML tags (indicative of an HTML README)
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
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))
  vim.api.nvim_buf_set_option(buf, "filetype", "markdown") -- Set syntax highlighting for Markdown

  -- Open a fullscreen floating window for the README content
  vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = vim.o.columns,
    height = vim.o.lines,
    col = 0,
    row = 0,
    style = "minimal",
    border = "none",
  })
end

return M

