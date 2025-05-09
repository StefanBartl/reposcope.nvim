--BUG: Stats are not correct

---@class ReposcopeMetrics
---@field req_count ReqCount Stores API request count for profiling purposes
---@field rate_limits RateLimits Stores the rate limits for the GitHub API (Core and Search)
---@field increase_req fun(query: string, source: string): nil Increases the request count for the current session and logs it
---@field increase_success fun(query: string, source: string, duration_ms: number, status_code: number): nil Increases the successful request count and logs it
---@field increase_failed fun(query: string, source: string, duration_ms: number, status_code: number, error: string): nil Increases the failed request count and logs it
---@field increase_cache_hit fun(query: string, source: string): nil Increases the cache hit count and logs it
---@field get_session_requests fun(): { total: number, successful: number, failed: number, cache_hitted: number } Retrieves the current session request count
---@field get_total_requests fun(): { total: number, successful: number, failed: number, cache_hitted: number } Retrieves the total request count from the file
---@field check_rate_limit fun(): nil Checks the current GitHub rate limit and displays a warning if low
local M = {}

---@class ReqCount Counts API requests for profiling purposes
---@field requests number Stores the total API request count for the current session
---@field successful number Stores the count of successful API requests for the current session
---@field failed number Stores the count of failed API requests for the current session
---@field cache_hitted number Stores the count of cache hits for the current session
M.req_count = {
  requests = 0,      -- Total API requests in this session
  successful = 0,    -- Successful API requests in this session
  failed = 0,        -- Failed API requests in this session
  cache_hitted = 0   -- Cache hits in this session
}

---@class RateLimits
---@field core RateLimitDetails The rate limit details for the GitHub Core API (general API requests)
---@field search RateLimitDetails The rate limit details for the GitHub Search API (search-related API requests)
---@class RateLimitDetails
---@field limit number The maximum number of requests allowed
---@field remaining number The remaining requests in the current rate limit window
---@field reset number The UNIX timestamp when the rate limit will reset
M.rate_limits = {
  core = {
    limit = 0,      -- The maximum number of requests allowed for the Core API
    remaining = 0,  -- The remaining requests available in this session
    reset = 0       -- The timestamp for rate limit reset (UNIX time)
  },
  search = {
    limit = 0,      -- The maximum number of requests allowed for the Search API
    remaining = 0,  -- The remaining requests available in this session
    reset = 0       -- The timestamp for rate limit reset (UNIX time)
  }
}

--- Retrieves the current session request counts
---@return { total: number, successful: number, failed: number, cache_hitted: number }
function M.get_session_requests()
  return {
    total = M.req_count.requests,
    successful = M.req_count.successful,
    failed = M.req_count.failed,
    cache_hitted = M.req_count.cache_hitted
  }
end

--- Retrieves the total request counts from the file
---@return { total: number, successful: number, failed: number, cache_hitted: number }
function M.get_total_requests()
  local state_path = require("reposcope.config").get_state_path()
  local file_path = vim.fn.fnameescape(state_path .. "/request_log.json")

  if not vim.fn.filereadable(file_path) then
    return { total = 0, successful = 0, failed = 0, cache_hitted = 0 }
  end

  local raw = vim.fn.readfile(file_path)
  local json_data = vim.json.decode(table.concat(raw, "\n")) or {}

  local total, successful, failed, cache_hitted = 0, 0, 0, 0

  for _, log in ipairs(json_data) do
    if log.type == "api_success" then
      successful = successful + 1
    elseif log.type == "api_failed" then
      failed = failed + 1
    elseif log.type == "cache_hit" then
      cache_hitted = cache_hitted + 1
    end
    total = total + 1
  end

  return {
    total = total,
    successful = successful,
    failed = failed,
    cache_hitted = cache_hitted
  }
end

--- Logs request details to request_log.json
---@param data table The request data to log
local function log_request(data)
  local state_path = require("reposcope.config").get_state_path()
  local file_path = vim.fn.fnameescape(state_path .. "/request_log.json")

  vim.schedule(function()
    vim.fn.mkdir(state_path, "p")

    local logs = {}
    if vim.fn.filereadable(file_path) == 1 then
      local raw = vim.fn.readfile(file_path)
      if raw and not vim.tbl_isempty(raw) then
        logs = vim.fn.json_decode(table.concat(raw, "\n"))
      end
    end

    table.insert(logs, data)

    -- Optional: Log rotieren, wenn zu groß
    if #logs > 1000 then
      table.remove(logs, 1)
    end

    vim.fn.writefile({ vim.json.encode(logs) }, file_path)
  end)
end

--- Increases the total request count for the current session and logs
function M.increase_req(query, source)
  M.req_count.requests = M.req_count.requests + 1
  log_request({
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    type = "api_request",
    query = query,
    source = source,
  })
end

--- Increases the successful request count
function M.increase_success(query, source, duration_ms, status_code)
  M.req_count.successful = M.req_count.successful + 1
  log_request({
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    type = "api_success",
    query = query,
    source = source,
    duration_ms = duration_ms,
    status_code = status_code
  })
end

--- Increases the failed request count
function M.increase_failed(query, source, duration_ms, status_code, error)
  M.req_count.failed = M.req_count.failed + 1
  log_request({
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    type = "api_failed",
    query = query,
    source = source,
    duration_ms = duration_ms,
    status_code = status_code,
    error_message = error
  })
end

--- Increases the cache hit count
function M.increase_cache_hit(query, source)
  M.req_count.cache_hitted = M.req_count.cache_hitted + 1
  log_request({
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    type = "cache_hit",
    query = query,
    source = source
  })
end

--- Checks the current GitHub rate limit and displays a warning if low
function M.check_rate_limit()
  if M.rate_limits.core.limit > 0 then
    local core_used = M.req_count.requests
    local core_usage = core_used / M.rate_limits.core.limit

    if core_usage >= 0.9 then
     vim.schedule(function()
       vim.notify("[Reposcope] WARNING: GitHub API Core limit critical (" .. core_used .. "/" .. M.rate_limits.core.limit .. ")", vim.log.levels.WARN)
     end)
    elseif core_usage >= 0.75 then
      vim.schedule(function()
        vim.notify("[Reposcope] INFO: GitHub API Core limit approaching (" .. core_used .. "/" .. M.rate_limits.core.limit .. ")", vim.log.levels.INFO)
      end)
    end
    return
  end

  -- If limits not set, fetch from API
  local http = require("reposcope.utils.http")
  local config = require("reposcope.config")
  local token = config.options.github_token

  local headers = { "Accept: application/vnd.github+json" }
  if token then
    table.insert(headers, "Authorization: Bearer " .. token)
  end

  http.get("https://api.github.com/rate_limit", function(response)
    if not response then
      vim.schedule(function()
        vim.notify("[Reposcope] Failed to fetch GitHub rate limit.", vim.log.levels.ERROR)
      end)
      return
    end

    local data = vim.json.decode(response)
    if data and data.resources then
      M.rate_limits.core.limit = data.resources.core.limit
      M.rate_limits.search.limit = data.resources.search.limit
      vim.schedule(function()
        vim.notify("[Reposcope] GitHub Rate Limits loaded.", vim.log.levels.INFO)
      end)
    end
  end)
end

return M
