---@module 'reposcope.@types.classes.providers'
---@brief Type definitions for provider modules (contracts every backend — GitHub, GitLab, Codeberg — must implement).

---@class ReadmeFetcherModule
---@field fetch_raw fun(owner: string, repo: string, branch: string, cb: fun(success: boolean, content: string|nil, err: string|nil): nil): nil # Fetches the README using the provider's raw content URL
---@field fetch_api fun(owner: string, repo: string, branch: string, cb: fun(success: boolean, content: string|nil, err: string|nil): nil): nil Fetches the README from the provider's API (base64-encoded)

---@class ReadmeManagerModule
---@field fetch_for_selected fun(uuid: string): nil Fetches the README for the currently selected repository

---@class ReadmeUrlBuilderModule
---@field get_urls fun(owner: string, repo: string, branch?: string): ReadmeURLs

---@class ClonerModule
---@field clone_repository fun(path: string, uuid: string): nil Starts the clone operation

---@class CloneInfo
---@field name string The name of the repository
---@field url string The repository's clone/web URL

---@class CloneManagerModule
---@field clone fun(path: string, uuid: string): nil Starts a clone operation for the selected repository

---@class CloneCommandBuilderModule
---@field build_command fun(clone_type: string, repo_url: string, output_dir: string): string[]

---@class QueryBuilderModule
---@field build fun(input: table<string, string>): string

---@class RepositoryFetcherModule
---@field build_url fun(query: string): string Builds the full provider API URL from the search query
---@field fetch_repositories fun(query: string, on_success: fun(): nil, on_failure: fun(): nil): nil Performs the API request and updates the cache

---@class RepositoryManagerModule
---@field fetch fun(query: string, uuid: string, on_success: (fun(): nil) | nil, on_failure: (fun(): nil) | nil): nil
---@field fetch_and_display fun(query: string, uuid: string, on_success: (fun(): nil) | nil, on_failure: (fun(): nil) | nil): nil Fetches repositories and updates the list UI

---@class ProviderEntrypoint The shape every `providers/<name>/entrypoint.lua` must export
---@field readme_manager ReadmeManagerModule
---@field repo_fetcher RepositoryManagerModule
---@field cloner CloneManagerModule
---@field query_builder QueryBuilderModule
