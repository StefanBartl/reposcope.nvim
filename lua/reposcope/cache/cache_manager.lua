--REF: refacore this file: get_repo. etc... from state/ to here

---@class CacheManager
---@field show_cached_readme fun(repo_name: string): boolean Shows README file if available in cache
---@field cache_and_show_readme fun(repo_name: string, content: string): nil Caches and displays the fetched README
local M = {}

-- Cache Management Modules
local readme_cache = require("reposcope.cache.readme_cache")
-- Utility Modules (Metrics, Core Functions, Debugging)
local metrics = require("reposcope.utils.metrics")
local core_utils = require("reposcope.utils.core")
local notify = require("reposcope.utils.debug").notify
-- UI Injection (Preview Manipulation)
local preview_manager = require("reposcope.ui.preview.preview_manager")


--- Displays cached README if available
---@param repo_name string Name of the repository for which a README file could be cached
---@return boolean Returns true if a README file is shown for given repository, false if not
function M.show_cached_readme(repo_name)
  local is_cached, source = readme_cache.has_cached_readme(repo_name)
  if is_cached then

    local uuid = core_utils.generate_uuid()   --REF: must this be here?
    if metrics.record_metrics() then
      if source == "ram" then
        metrics.increase_cache_hit(uuid, repo_name, repo_name, "fetch_readme")
      elseif source == "file" then
        metrics.increase_fcache_hit(uuid, repo_name, repo_name, "fetch_readme")
      end
    end

    vim.schedule(function()
      preview_manager.update_preview(repo_name)
    end)

    readme_cache.active_readme_requests[repo_name] = nil
    return true
  end
  return false
end


--- Caches and displays the fetched README content
---@param repo_name string The name of the repository
---@param content string The README content to cache
function M.cache_and_show_readme(repo_name, content)
  readme_cache.cache_readme(repo_name, content) --NOTE: pcall

  -- Write to file cache asynchronously
  vim.schedule(function()
    readme_cache.fcache_readme(repo_name, content) -- NOTE: pcall
    notify("[reposcope] README cached to file: " .. repo_name, 1)
  end)

  preview_manager.update_preview(repo_name)
  notify("[reposcope] Successfully fetched README")
end

return M
