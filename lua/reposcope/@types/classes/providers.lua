---@module 'reposcope.@types.classes.providers'
---@brief Type definitions for GitHub provider modules.

---@class ReadmeFetcherModule
---@field fetch_raw fun(owner: string, repo: string, branch: string, cb: fun(success: boolean, content: string|nil, err: string|nil): nil, uuid: UUID): nil # Fetches the README using the raw Github URL
---@field fetch_api fun(owner: string, repo: string, branch: string, cb: fun(success: boolean, content: string|nil, err: string|nil): nil, uuid: UUID): nil Fetches the README from the GitHub API (base64-encoded)

---@class ReadmeManagerModule
---@field fetch_for_selected fun(uuid: string): nil Fetches the README for the currently selected repository

---@class ReadmeUrlBuilderModule
---@field get_urls fun(owner: string, repo: string, branch?: string): ReadmeURLs

---@class GithubClonerModule
---@field clone_repository fun(path: string, uuid: string): nil Starts the clone operation

---@class CloneInfo
---@field name string The name of the repository
---@field url string The URL of the repository

---@class QueryBuilderModule
---@field build fun(input: table<string, string>): string

---@class GithubRepositoriesModule
---@field fetch_repositories fun(query: string, uuid: string): nil Fetches repositories from GitHub API based on a query
---@field build_cmd fun(query: string): string[] Builds the API request for GitHub repo search
