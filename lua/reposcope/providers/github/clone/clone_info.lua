---@module 'reposcope.providers.github.clone.clone_info'
---@brief Extracts repository name and URL for cloning.
---@description
--- Returns basic information needed for cloning the currently selected repository:
--- name and URL. Validates presence and structure before use.

---@class GithubCloneInfo : GithubCloneInfoModule
local M = {}

local notify = require("reposcope.utils.debug").notify


---Gets the name and URL of the selected repository
---@return CloneInfo|nil
function M.get_clone_informations()
  local repo = require("reposcope.cache.repository_cache").get_selected()
  if not repo then
    notify("[reposcope] Error cloning: Repository is nil", 4)
    return nil
  end

  local name = repo.name or ""
  local url = repo.html_url or ""

  if name == "" then
    notify("[reposcope] Error cloning: Repository name is invalid", 4)
    return nil
  end

  if url == "" then
    notify("[reposcope] Error cloning: Repository URL is invalid", 4)
    return nil
  end

  return { name = name, url = url }
end

return M
