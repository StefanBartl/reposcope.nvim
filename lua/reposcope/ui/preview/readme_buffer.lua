--- @class UIShowReadme
--- @field create fun(): nil Displays the README of the selected repository in a hidden Neovim buffer (Markdown) or a browser (HTML)
local M = {}

local debug = require("reposcope.utils.debug")
local readme_state = require("reposcope.state.readme")
local repositories = require("reposcope.state.repositories")
local os = require("reposcope.utils.os")

--- Displays the README of the currently selected repository.
--- If the README contains HTML content, it opens in the default web browser.
--- If the README is Markdown, it is created as a hidden buffer (background).
function M.create()
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
  if not content then
    content = readme_state.get_fcached_readme(repo_name)
    if not content then
      debug.notify("[reposcope] README not filecached for: " .. repo_name, 4)
      content = "README not cached yet."
    end
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
    local url = "https://github.com/" .. repo.owner.login .. "/" .. repo_name
    os.open_url(url)
    return
  end

  -- Create a hidden buffer for the README content
  local buf = vim.api.nvim_create_buf(true, false) -- No window attached
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))

  -- Set the buffer name (pseudo-path)
  vim.api.nvim_buf_set_name(buf, "reposcope://README.md (" .. repo_name .. ")")

  -- Set buffer options (Markdown format)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].modifiable = true
  vim.bo[buf].readonly = false
  vim.bo[buf].buftype = "" -- Normal buffer type

  -- Debug: Info über den verborgenen Buffer
  debug.notify("[reposcope] README buffer created: reposcope://README.md (" .. repo_name .. ")", 2)
end

return M
