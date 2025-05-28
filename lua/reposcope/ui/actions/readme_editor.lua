---@class ActionCreateReadmeEditor
---@brief Creates a hidden buffer containing the README content
---@description
--- This action loads the README content (from RAM or file cache) and places it in a hidden Neovim buffer.
--- It is triggered by a keymap and is useful for later reviewing or scripting (e.g., extract, export).
---@field open_editor fun(): nil Loads and buffers the README content in a detached bufferlocal M = {}
local M  = {}

-- Debugging Utility
local notify = require("reposcope.utils.debug").notify
-- Caching (Readme Cache Management)
local readme_cache = require("reposcope.cache.readme_cache")
-- Cache Management
local repository_cache = require("reposcope.cache.repository_cache")
-- OS Utilities (Operating System Commands)
local os = require("reposcope.utils.os")


---Creates a hidden buffer with the README content of the selected repository.
---@return nil
function M.open_editor()
  local repo = repository_cache.get_selected()
  if not repo or not repo.name then
    notify("[reposcope] No repository selected or invalid.", 3)
    return
  end

  local repo_name = repo.name

  -- Try loading from cache
  local content = readme_cache.get_cached_readme(repo_name)
  if not content then
    notify("[reposcope] README not cached for: " .. repo_name, 3)
    content = readme_cache.get_fcached_readme(repo_name)
    if not content then
      notify("[reposcope] README not filecached for: " .. repo_name, 3)
      content = "README not cached yet."
    end
  end

  -- Open in browser if HTML-like
  if content:match("<html>") or content:match("<head>") or content:match("<body>") or content:match("<div>") then
    local url = "https://github.com/" .. repo.owner.login .. "/" .. repo_name
    os.open_url(url)
    return
  end

  local buf = vim.api.nvim_create_buf(true, false) -- No window attached
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))

  -- Annotate buffer
  vim.api.nvim_buf_set_name(buf, "reposcope://README.md (" .. repo_name .. ")")

  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].modifiable = true
  vim.bo[buf].readonly = false
  vim.bo[buf].buftype = ""
end

return M
