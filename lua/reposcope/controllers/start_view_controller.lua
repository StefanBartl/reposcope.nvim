---@module 'reposcope.controllers.start_view_controller'
---@brief Populates the repository list with favorites on a fresh UI open.
---@description
--- Reposcope used to always start from an empty prompt and an empty list —
--- every `:Reposcope start` began at zero, even with favorites already
--- persisted. `M.show_favorites_if_any()`, called once from `init.open_ui()`,
--- converts the persisted favorites into a `Repository[]` and feeds them
--- through the exact same display path a real search result would use
--- (`repository_cache.set` + `list_controller.display_repositories`), so
--- list navigation, README preview, sorting and filtering all work
--- identically on the start view as on a real search result.
---
--- Favorite READMEs were already snapshotted at toggle time
--- (`favorites_state.toggle`), so they're pre-warmed into `readme_cache`'s
--- RAM store before the first `fetch_readme_for_selected()` call — the
--- existing `readme_manager` already checks the cache before ever hitting
--- the network (`has(owner, repo_name)`), so this needs no special-cased
--- preview path; the win is automatic.

---@class StartViewController : StartViewControllerModule
local M = {}

local favorites_state = require("reposcope.state.favorites_state")
local repository_cache = require("reposcope.cache.repository_cache")
local readme_cache = require("reposcope.cache.readme_cache")
local list_controller = require("reposcope.controllers.list_controller")
local notify = require("reposcope.utils.debug").notify

---@private
---@internal
---@param fav FavoriteRepo
---@return Repository
local function to_repository(fav)
  return {
    name = fav.name,
    description = fav.description,
    html_url = fav.html_url,
    owner = { login = fav.owner },
    default_branch = fav.default_branch,
    stargazers_count = fav.stargazers_count,
  }
end

---Populates the list with favorited repositories, if any, and warms the
--- preview for the first entry. No-op (returns `false`) if there are none —
--- the caller falls back to the normal empty-prompt start.
---@return boolean shown
function M.show_favorites_if_any()
  local favorites = favorites_state.list()
  if #favorites == 0 then return false end

  ---@type Repository[]
  local items = {}
  for i, fav in ipairs(favorites) do
    items[i] = to_repository(fav)
    if fav.readme then readme_cache.set_ram(fav.owner, fav.name, fav.readme) end
  end

  repository_cache.set({ total_count = #items, items = items }, true)
  list_controller.display_repositories()
  require("reposcope.controllers.provider_controller").fetch_readme_for_selected()

  notify(("[reposcope] Showing %d favorite%s"):format(#items, #items == 1 and "" or "s"), 2)
  return true
end

return M
