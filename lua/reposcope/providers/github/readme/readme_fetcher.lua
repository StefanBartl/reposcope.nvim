---@module 'reposcope.providers.github.readme.readme_fetcher'
---@brief Downloads README content from GitHub using raw URL or API fallback
---@description
--- This module provides functions to fetch a README either from the raw GitHub URL
--- or from the GitHub API endpoint as a fallback. Each function is purely responsible
--- for HTTP communication and decoding and does not interact with cache or UI.
---
--- All responses are returned through callback functions, ensuring that calling
--- modules can schedule or process as needed.

---@class ReadmeFetcher :ReadmeFetcherModule
local M = {}

-- Network utilities
local request = require("reposcope.network.clients.api_client").request
local decode_base64 = require("reposcope.utils.encoding").decode_base64
local get_urls = require("reposcope.providers.github.readme.readme_urls").get_urls


---Fetches the README using the raw GitHub URL
---@param owner string Repository owner
---@param repo string Repository name
---@param branch string Target branch (e.g., "main")
---@param cb fun(success: boolean, content: string|nil, err: string|nil): nil Callback receiving result
---@param uuid string Unique request identifier
---@return nil
function M.fetch_raw(owner, repo, branch, cb, uuid)
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
  end, nil, "readme_fetch_raw", uuid)
end


---Fetches the README from the GitHub API (base64-encoded)
---@param owner string Repository owner
---@param repo string Repository name
---@param branch string Target branch (e.g., "main")
---@param cb fun(success: boolean, content: string|nil, err: string|nil): nil Callback receiving result
---@param uuid string Unique request identifier
---@return nil
function M.fetch_api(owner, repo, branch, cb, uuid)
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
  end, nil, "readme_fetch_api", uuid)
end

return M
