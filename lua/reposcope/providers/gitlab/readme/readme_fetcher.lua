---@module 'reposcope.providers.gitlab.readme.readme_fetcher'
---@brief Downloads README content from GitLab using raw URL or API fallback
---@description
--- This module provides functions to fetch a README either from GitLab's raw
--- file URL or from the GitLab API's repository-files endpoint (base64) as a
--- fallback. Each function is purely responsible for HTTP communication and
--- decoding and does not interact with cache or UI.

---@class GitlabReadmeFetcher : ReadmeFetcherModule
local M = {}

-- Network utilities
local request = require("reposcope.network.clients.api_client").request
local decode_base64 = require("reposcope.utils.encoding").decode_base64
local get_urls = require("reposcope.providers.gitlab.readme.readme_urls").get_urls


---Fetches the README using GitLab's raw file URL
---@param owner string Repository namespace
---@param repo string Repository name
---@param branch string Target branch (e.g., "main")
---@param cb fun(success: boolean, content: string|nil, err: string|nil): nil Callback receiving result
---@return nil
function M.fetch_raw(owner, repo, branch, cb)
  local urls = get_urls(owner, repo, branch)
  if not urls or not urls.raw then
    cb(false, nil, "Missing raw URL")
    return
  end

  request("GET", urls.raw, function(response, err)
    if err or not response then
      cb(false, nil, nil) -- Silent failure, no error shown to user
      return
    end
    cb(true, response)
  end, nil, "readme_fetch_raw")
end


---Fetches the README from the GitLab API (base64-encoded)
---@param owner string Repository namespace
---@param repo string Repository name
---@param branch string Target branch (e.g., "main")
---@param cb fun(success: boolean, content: string|nil, err: string|nil): nil Callback receiving result
---@return nil
function M.fetch_api(owner, repo, branch, cb)
  local urls = get_urls(owner, repo, branch)
  if not urls or not urls.api then
    cb(false, nil, "Missing API URL")
    return
  end

  request("GET", urls.api, function(response, err)
    if err or not response then
      cb(false, nil, nil) -- Silent fallback
      return
    end

    local ok, decoded = pcall(vim.json.decode, response)
    if not ok or not decoded or not decoded.content then
      cb(false, nil, "Invalid JSON or missing content")
      return
    end

    local content = decode_base64(decoded.content)
    cb(true, content)
  end, nil, "readme_fetch_api")
end

return M
