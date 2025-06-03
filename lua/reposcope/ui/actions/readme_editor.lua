---@module 'reposcope.ui.actions.readme_editor'
---@brief Creates a hidden buffer containing the README content
---@description
--- This action loads the README content (from RAM or file cache) and places it in a hidden Neovim buffer.
--- It is triggered by a keymap and is useful for later reviewing or scripting (e.g., extract, export).

---@class ActionCreateReadmeEditor : ActionCreateReadmeEditorModule
local M  = {}

-- Vim Utilities
local nvim_create_buf  = vim.api.nvim_create_buf
local nvim_buf_set_lines = vim.api.nvim_buf_set_lines
local nvim_buf_set_name = vim.api.nvim_buf_set_name
-- Debugging Utility
local notify = require("reposcope.utils.debug").notify
-- Cache Management
local cache_get_file = require("reposcope.cache.readme_cache").get_file
local cache_get_ram = require("reposcope.cache.readme_cache").get_ram
local cache_get_selected_repo = require("reposcope.cache.repository_cache").get_selected
-- OS Utilities
local os = require("reposcope.utils.os")


---Creates a hidden buffer with the README content of the selected repository.
---@return nil
function M.open_editor()
  local repo = cache_get_selected_repo()
  if not repo or not repo.name then
    notify("[reposcope] No repository selected or invalid.", 3)
    return
  end

  local repo_name = repo.name

  -- Try loading from cache
  local content = cache_get_ram(repo_name)
  if not content then
    notify("[reposcope] README not cached for: " .. repo_name, 3)
    content = cache_get_file(repo_name)
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

  local buf = nvim_create_buf(true, false) -- No window attached
  nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))

  -- Annotate buffer
  nvim_buf_set_name(buf, "reposcope://README.md (" .. repo_name .. ")")

  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].modifiable = true
  vim.bo[buf].readonly = false
  vim.bo[buf].buftype = ""
end

return M
