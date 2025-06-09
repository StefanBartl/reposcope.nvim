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
---@field clear_all fun(): boolean Clears all README cache entries (RAM and file)

---@class RepositoryOwner
---@field login string Owner login name

---@class Repository
---@field name string Repository name
---@field description string Repository description
---@field html_url string Repository URL
---@field owner RepositoryOwner Owner of the repository
---@field default_branch? string The default branch of the repository (optional)
---@field stargazers_count? number

---@class RepositoryResponse
---@field total_count number Total number of repositories found
---@field items Repository[] List of repositories
---@field list string[] List of all repositories with most important informations

---@class RepositoryCacheModule
---@field set fun(json: RepositoryResponse, is_original?: boolean): nil Caches the repository response
---@field get fun(): RepositoryResponse Returns the currently cached repositories
---@field get_by_name fun(repo_name: string): Repository|nil Returns a repository object by name
---@field get_selected fun(): Repository|nil Returns the currently selected repository
---@field get_list fun(): string[] Returns the display-ready list for the UI
---@field clear fun(): nil Clears the repository cache
