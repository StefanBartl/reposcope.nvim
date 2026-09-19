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
local read_file = require("lib.nvim.fs.read")
local write_to_file = require("lib.nvim.fs.write.to_file")
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

  -- `or 1000` alone only catches nil/false: a wrong-type value (e.g. a
  -- string typo'd in setup()) would sail through and then crash the
  -- `vim.tbl_count(logs) > log_max` comparison below with "attempt to
  -- compare number with string" (ERR-22). A non-positive number is also
  -- rejected here, not just a non-number, so it degrades the same way a
  -- missing value does rather than trimming the log to nothing on every
  -- write.
  local log_max = config.options.log_max
  if type(log_max) ~= "number" or log_max <= 0 then log_max = 1000 end
  local log_path = config.get_option("logfile_path")

  if not log_path then
    notify("[reposcope] log_path for log_request() is invalid.", 2)
    return
  end

  vim.schedule(function()
    local logs = {}

    -- Read existing log file if available
    if is_readable_file(log_path) then
      local decoded_logs, read_err = fs_json.read(log_path)
      if type(decoded_logs) == "table" then
        logs = decoded_logs
      else
        -- decoded_logs is nil here for two very different reasons: the file
        -- is empty (nothing lost, nothing to say) or it exists with content
        -- that failed to decode (genuinely corrupt). This function is a
        -- load-modify-save cycle -- fs_json.write() below unconditionally
        -- rewrites the whole file -- so collapsing both onto the same
        -- "start fresh" path would mean the very next request silently
        -- replaces a corrupt request_log.json with a single-entry log, with
        -- no trace the earlier entries ever existed. Back up the original
        -- bytes once before falling back to an empty log (ERR-11; same
        -- idiom as cmdlog.nvim's store.lua/favorites.lua).
        local raw_content = read_file(log_path)
        if raw_content and raw_content ~= "" then
          local backup_path = log_path .. ".corrupt"
          local backup_note
          if is_readable_file(backup_path) then
            backup_note = "original already kept at '" .. backup_path .. "'"
          else
            local backed_up, backup_err = write_to_file(backup_path, raw_content)
            -- The notice must not claim a backup exists when the write
            -- itself failed (e.g. a full disk or a read-only mount).
            backup_note = backed_up and ("original kept at '" .. backup_path .. "'")
              or ("failed to back up original: " .. tostring(backup_err))
          end
          notify(
            ("[reposcope] '%s' is not valid JSON (%s); %s"):format(log_path, tostring(read_err), backup_note),
            vim.log.levels.ERROR
          )
        end
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

    -- The response body is a network boundary -- decode it inside a pcall,
    -- same as every other decode site in the plugin (ERR-01).
    local ok, data = pcall(decode, response)
    if not ok or type(data) ~= "table" or type(data.resources) ~= "table" then
      vim.schedule(function() notify("[Reposcope] Invalid rate limit response from GitHub.", 4) end)
      return
    end

    local core = data.resources.core
    local search = data.resources.search
    if type(core) ~= "table" or type(search) ~= "table" then
      vim.schedule(function() notify("[Reposcope] Rate limit response missing core/search data.", 4) end)
      return
    end

    M.rate_limits.core.limit = core.limit
    M.rate_limits.core.remaining = core.remaining
    M.rate_limits.core.reset = core.reset

    M.rate_limits.search.limit = search.limit
    M.rate_limits.search.remaining = search.remaining
    M.rate_limits.search.reset = search.reset
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
