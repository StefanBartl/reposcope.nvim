---@module 'reposcope.@types.classes.providers'
---@brief Type definitions for GitHub provider modules.

---@class ReadmeFetcherModule
---@field fetch_raw fun(owner: string, repo: string, branch: string, cb: fun(success: boolean, content: string|nil, err: string|nil): nil): nil # Fetches the README using the raw Github URL
---@field fetch_api fun(owner: string, repo: string, branch: string, cb: fun(success: boolean, content: string|nil, err: string|nil): nil): nil Fetches the README from the GitHub API (base64-encoded)

---@class ReadmeManagerModule
---@field fetch_for_selected fun(uuid: string): nil Fetches the README for the currently selected repository

---@class ReadmeUrlBuilderModule
---@field get_urls fun(owner: string, repo: string, branch?: string): ReadmeURLs

---@class GithubClonerModule
---@field clone_repository fun(path: string, uuid: string): nil Starts the clone operation

---@class CloneInfo
---@field name string The name of the repository
---@field url string The GitHub URL of the repository

---@class GithubCloneManagerModule
---@field clone fun(path: string, uuid: string): nil Starts a clone operation for the selected repository

---@class GithubCloneInfoModule
---@field get_clone_informations fun(): CloneInfo|nil

---@class GithubCloneCommandBuilderModule
---@field build_command fun(clone_type: string, repo_url: string, output_dir: string): string

---@class GithubCloneExecutorModule
---@field execute fun(cmd: string, uuid: string, repo_name: string): nil

---@class QueryBuilderModule
---@field build fun(input: table<string, string>): string

---@class GithubRepositoryFetcherModule
---@field build_url fun(query: string): string Builds the full GitHub API URL from the search query
---@field fetch_repositories fun(query: string, uuid: string, on_success: fun(): nil, on_failure: fun(): nil): nil Performs the API request and updates the cache

---@class GithubRepositoryUILoaderModule
---@field load_ui_after_fetch fun(): nil Populates the list UI and optionally triggers README load

---@class GithubRepositoryManagerModule
---@field fetch fun(query: string, uuid: string, on_success?: fun(): nil, on_failure?: fun(): nil): nil Fetches repositories without UI
---@field fetch_and_display fun(query: string, uuid: string, on_failure?: fun(): nil): nil Fetches repositories and updates the list UI
