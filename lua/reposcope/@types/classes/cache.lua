---@module 'reposcope.@types.classes.cache'
---@brief Type definitions for user cache modules

---@class ReadmeCacheModule
---@brief Caches README content for repositories in RAM and file.
---@description
--- Handles all cache operations for repository READMEs.
--- Includes RAM- and file-based caching as well as inspection and clearing.
---@alias Readme table<string, string>
---@field readme_cache table<string, string> Readme RAM cache for fetched README contents (keyed by "owner/repo")
---@field get fun(owner: string, repo_name: string): string|nil Returns README content from cache (RAM or file)
---@field has fun(owner: string, repo_name: string): boolean, "ram"|"file"|nil Checks if README exists in cache
---@field set_ram fun(owner: string, repo_name: string, text: string): nil Stores README in RAM cache
---@field get_ram fun(owner: string, repo_name: string): string|nil Retrieves README from RAM cache
---@field set_file fun(owner: string, repo_name: string, text: string): boolean Saves README to file cache
---@field get_file fun(owner: string, repo_name: string): string|nil Loads README from file cache
---@field clear fun(owner: string, repo_name: string, target?: "ram"|"file"|"both"): boolean Clears README cache (RAM/file)
---@field clear_all fun(): boolean Clears all README cache entries (RAM, file, and freshness metadata)
---@field get_cached_updated_at fun(owner: string, repo_name: string): string|nil Returns the repository `updated_at` recorded when its README was last cached
---@field set_updated_at fun(owner: string, repo_name: string, updated_at: string|nil): nil Records the repository `updated_at` a README was cached under
---@field has_fresh fun(owner: string, repo_name: string, updated_at: string|nil): boolean, "ram"|"file"|nil Like `has`, but also treats the cache as a miss if `updated_at` differs from the value recorded at cache time
---@field warm_ram_from_file_cache fun(): integer Preloads every file-cached README into the RAM cache; returns how many were loaded

---@class RepositoryOwner
---@field login string Owner login name

---@class Repository
---@field name string Repository name
---@field description string Repository description
---@field html_url string Repository URL
---@field owner RepositoryOwner Owner of the repository
---@field default_branch? string The default branch of the repository (optional)
---@field stargazers_count? number
---@field updated_at? string ISO8601 timestamp of the repository's last update (GitHub: `updated_at`, GitLab: `last_activity_at`, Codeberg: `updated_at`); used to detect a stale cached README

---@class RepositoryResponse
---@field total_count number Total number of repositories found
---@field items Repository[] List of repositories
---@field list string[] List of all repositories with most important informations

---@class FavoriteRepo A persisted snapshot of a favorited repository (metadata + README, if cached at toggle time)
---@field owner string
---@field name string
---@field description string
---@field html_url string
---@field default_branch? string
---@field stargazers_count? number
---@field readme? string README content cached at the time the repository was favorited, if any

---@class RepositoryCacheModule
---@field set fun(json: RepositoryResponse, is_original?: boolean): nil Caches the repository response
---@field get fun(): RepositoryResponse Returns the currently cached repositories
---@field get_by_name fun(repo_name: string): Repository|nil Returns a repository object by name
---@field get_selected fun(): Repository|nil Returns the currently selected repository
---@field get_list fun(): string[] Returns the display-ready list for the UI
---@field clear fun(): nil Clears the repository cache
