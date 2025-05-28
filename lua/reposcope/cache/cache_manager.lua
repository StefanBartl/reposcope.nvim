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

    local uuid = core_utils.generate_uuid()
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
---@return nil
function M.cache_and_show_readme(repo_name, content)
  -- Try caching in memory
  local ok_mem, err_mem = pcall(readme_cache.cache_readme, repo_name, content)
  if not ok_mem then
    notify("[reposcope] Failed to cache README in memory: " .. tostring(err_mem), vim.log.levels.WARN)
  end

  -- Write to file cache asynchronously
  vim.schedule(function()
    local ok_file, err_file = pcall(readme_cache.fcache_readme, repo_name, content)
    if not ok_file then
      notify("[reposcope] Failed to write README to file cache: " .. tostring(err_file), vim.log.levels.WARN)
    else
      notify("[reposcope] README cached to file: " .. repo_name, vim.log.levels.INFO)
    end
  end)

  -- Update preview buffer
  local ok_preview, err_preview = pcall(preview_manager.update_preview, repo_name)
  if not ok_preview then
    notify("[reposcope] Failed to update preview for " .. repo_name .. ": " .. tostring(err_preview), vim.log.levels.ERROR)
  else
    notify("[reposcope] Successfully fetched README", vim.log.levels.INFO)
  end
end

return M
