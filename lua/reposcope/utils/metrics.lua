---@module 'reposcope.utils.metrics'
---@brief Tracks and logs all API-related request metrics, rate limits, and cache hits in Reposcope.
---@see reposcope.types.classes.utils

---@class ReposcopeMetrics : ReposcopeMetricsModule
---@see reposcope.types.classes.utils
local M = {}

-- Vim Utilities
local fs_stat = vim.uv.fs_stat
local decode = vim.json.decode
-- lib.nvim
local is_readable_file = require("lib.nvim.fs.is_readable_file")
local fs_json = require("lib.nvim.fs.json")
-- Project Imports
local notify = require("reposcope.utils.debug").notify
local config = require("reposcope.config")

---@type ReqCount
M.req_count = {
  successful = 0, -- Successful API requests in this session
  failed = 0, -- Failed API requests in this session
  cache_hitted = 0, -- Cache hits in this session
  fcache_hitted = 0, -- Filecache hits in this session
}

---@type RateLimits
M.rate_limits = {
  core = {
    limit = 0, -- The maximum number of requests allowed for the Core API
    remaining = 0, -- The remaining requests available in this session
    reset = 0, -- The timestamp for rate limit reset (UNIX time)
  },
  search = {
    limit = 0, -- The maximum number of requests allowed for the Search API
    remaining = 0, -- The remaining requests available in this session
    reset = 0, -- The timestamp for rate limit reset (UNIX time)
  },
}

---Retrieves the current session request counts
---@return RequestMetricsData
function M.get_session_requests()
  return {
    successful = M.req_count.successful,
    failed = M.req_count.failed,
    cache_hitted = M.req_count.cache_hitted,
    fcache_hitted = M.req_count.fcache_hitted,
  }
end

---Retrieves the total request counts from the file
---@return RequestMetricsData
function M.get_total_requests()
  local log_path = config.get_option("logfile_path")
  if not log_path then
    notify("[reposcope] Stats not available, logfile path invalid", 4)
    return { successful = 0, failed = 0, cache_hitted = 0, fcache_hitted = 0 }
  end

  if not is_readable_file(log_path) then return { successful = 0, failed = 0, cache_hitted = 0, fcache_hitted = 0 } end

  local file_stats = fs_stat(log_path)
  if file_stats and file_stats.size == 0 then
    return { successful = 0, failed = 0, cache_hitted = 0, fcache_hitted = 0 }
  end

  local json_data, err = fs_json.read(log_path)
  if not json_data then
    notify("[reposcope] Error reading stats file: " .. tostring(err), 4)
    return { successful = 0, failed = 0, cache_hitted = 0, fcache_hitted = 0 }
  end

  local successful, failed, cache_hitted, fcache_hitted = 0, 0, 0, 0

  for _, log in pairs(json_data) do
    if log.type == "api_success" then
      successful = successful + 1
    elseif log.type == "api_failed" then
      failed = failed + 1
    elseif log.type == "cache_hit" then
      cache_hitted = cache_hitted + 1
    elseif log.type == "filecache_hit" then
      fcache_hitted = fcache_hitted + 1
    end
  end

  return {
    successful = successful,
    failed = failed,
    cache_hitted = cache_hitted,
    fcache_hitted = fcache_hitted,
  }
end

---@private
---@internal
---Logs request details to request_log.json in JSON object format
---@param uuid UUID request identifier
---@param data table The request data to log
---@return nil
local function log_request(uuid, data)
  -- Sicherstellen, dass uuid ein String ist
  if type(uuid) ~= "string" then
    notify("[reposcope] Invalid UUID type. Expected string, got " .. type(uuid), vim.log.levels.ERROR)
    return
  end

  local log_max = config.options.log_max or 1000
  local log_path = config.get_option("logfile_path")

  if not log_path then
    notify("[reposcope] log_path for log_request() is invalid.", 2)
    return
  end

  vim.schedule(function()
    local logs = {}

    -- Read existing log file if available
    if is_readable_file(log_path) then
      local decoded_logs = fs_json.read(log_path)
      if type(decoded_logs) == "table" then
        logs = decoded_logs
      else
        notify("[reposcope] Invalid JSON format in log file. Starting fresh log.", vim.log.levels.WARN)
      end
    end

    -- Ensure logs is always a table
    if type(logs) ~= "table" then logs = {} end

    -- Add new log entry
    local log_key = uuid .. ":" .. (data.type or "unknown")
    logs[log_key] = data

    -- Remove oldest entry if too many logs exist
    if vim.tbl_count(logs) > log_max then
      local oldest_key = next(logs)
      if oldest_key then logs[oldest_key] = nil end
    end

    -- Encode and save logs to file with formatted JSON
    local ok, err = fs_json.write(log_path, logs)
    if not ok then
      notify("[reposcope] Failed to write logs to JSON: " .. tostring(err), 5)
      return
    end
  end)
end

---Increases the successful request count
---@param uuid UUID
---@param query Query
---@param source string
---@param context string
---@param duration_ms number
---@param status_code number
---@param url? string The actual request URL, if available (logged verbatim, not derived from `query`/`source`)
---@return nil
function M.increase_success(uuid, query, source, context, duration_ms, status_code, url)
  M.req_count.successful = M.req_count.successful + 1
  log_request(uuid, {
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    type = "api_success",
    query = query,
    source = source,
    context = context,
    duration_ms = duration_ms,
    status_code = status_code,
    url = url,
  })
end

---Increases the failed request count
---@param uuid UUID
---@param query Query
---@param source string
---@param context string
---@param duration_ms number
---@param status_code number
---@param error string
---@param url? string The actual request URL, if available (logged verbatim, not derived from `query`/`source`)
---@return nil
function M.increase_failed(uuid, query, source, context, duration_ms, status_code, error, url)
  M.req_count.failed = M.req_count.failed + 1
  log_request(uuid, {
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    type = "api_failed",
    query = query,
    source = source,
    context = context,
    duration_ms = duration_ms,
    status_code = status_code,
    error_message = error,
    url = url,
  })
end

---Increases the cache hit count
---@param uuid UUID
---@param query Query
---@param source string
---@param context string
---@param url? string The repository URL, if available
---@return nil
function M.increase_cache_hit(uuid, query, source, context, url)
  M.req_count.cache_hitted = M.req_count.cache_hitted + 1
  log_request(uuid, {
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    type = "cache_hit",
    query = query,
    source = source,
    context = context,
    url = url,
  })
end

---Increases the cache hit count
---@param uuid UUID
---@param query Query
---@param source string
---@param context string
---@param url? string The repository URL, if available
---@return nil
function M.increase_fcache_hit(uuid, query, source, context, url)
  M.req_count.fcache_hitted = M.req_count.fcache_hitted + 1
  log_request(uuid, {
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    type = "filecache_hit",
    query = query,
    source = source,
    context = context,
    url = url,
  })
end

---Checks the current GitHub rate limit and displays a warning if low
---@return nil
function M.check_rate_limit()
  if M.rate_limits.core.limit > 0 and M.rate_limits.search.limit > 0 then
    local core_used = M.req_count.successful + M.req_count.failed
    local core_remaining = M.rate_limits.core.remaining
    local core_limit = M.rate_limits.core.limit
    local core_usage = 1 - (core_remaining / core_limit)

    if core_usage >= 0.9 then
      vim.schedule(
        function()
          notify(
            ("[Reposcope] WARNING: GitHub API Core limit critical.\n" .. "  Used: %d  Limit: %d  Remaining: %d"):format(
              core_used,
              core_limit,
              core_remaining
            ),
            3
          )
        end
      )
    elseif core_usage >= 0.75 then
      vim.schedule(
        function()
          notify(
            ("[Reposcope] INFO: GitHub API Core limit approaching.\n" .. "  Used: %d  Limit: %d  Remaining: %d"):format(
              core_used,
              core_limit,
              core_remaining
            ),
            2
          )
        end
      )
    end

    local search_remaining = M.rate_limits.search.remaining
    local search_limit = M.rate_limits.search.limit
    local search_usage = 1 - (search_remaining / search_limit)

    if search_usage >= 0.9 then
      vim.schedule(
        function()
          notify("[Reposcope] WARNING: GitHub API Search limit critical (remaining: " .. search_remaining .. ")", 3)
        end
      )
    elseif search_usage >= 0.75 then
      vim.schedule(
        function()
          notify("[Reposcope] INFO: GitHub API Search limit approaching (remaining: " .. search_remaining .. ")", 2)
        end
      )
    end

    return
  end

  -- Fallback: Fetch new rate limit data
  local api_request = require("reposcope.network.clients.api_client").request
  local token = config.options.github_token
  local headers = {}

  if token and token ~= "" then headers["Authorization"] = "Bearer " .. token end

  api_request("GET", "https://api.github.com/rate_limit", function(response, err)
    if err or not response then
      vim.schedule(function() notify("[Reposcope] Failed to fetch GitHub rate limit.", 4) end)
      return
    end

    local data = decode(response)
    if data and data.resources then
      M.rate_limits.core.limit = data.resources.core.limit
      M.rate_limits.core.remaining = data.resources.core.remaining
      M.rate_limits.core.reset = data.resources.core.reset

      M.rate_limits.search.limit = data.resources.search.limit
      M.rate_limits.search.remaining = data.resources.search.remaining
      M.rate_limits.search.reset = data.resources.search.reset
    end
  end, headers)
end

---Returns the current record metrics state
---@return boolean The current record metrics state
function M.record_metrics() return config.options.metrics end

---Toogle the current record metrics state
---@return boolean The current record metrics state
function M.toggle_record_metrics()
  config.options.metrics = not config.options.metrics
  return config.options.metrics
end

---Set the current record metrics state
---@param bool boolean Boolean value to set record metrics state
---@return boolean The current record metrics state
function M.set_record_metrics(bool)
  config.options.metrics = bool
  return config.options.metrics
end

return M
