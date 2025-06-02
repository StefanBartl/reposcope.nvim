---@module 'reposcope.@types.classes.utils'
---@brief Class definitions for all utility modules in `reposcope.utils`



--- === metrics.lua ===

---@class ReposcopeMetricsModule
---@field req_count ReqCount Stores API request count for profiling purposes
---@field rate_limits RateLimits Stores the rate limits for the GitHub API (Core and Search)
---@field log_request fun(uuid: string, data: table): nil Logs request details to request_log.json in JSON object format
---@field increase_success fun(uuid: string, query: string, source: string, context: string, duration_ms: number, status_code: number) Increases the succes request count and logs it
---@field increase_failed fun(uuid: string, query: string, source: string, context: string, duration_ms: number, status_code: number, error?: string|nil): nil Increases the failed request count and logs it
---@field increase_cache_hit fun(uuid: string, query: string, source: string, context: string): nil Increases the cache hit count and logs it
---@field increase_fcache_hit fun(uuid: string, query: string, source: string, context: string): nil Increases the filecache hit count and logs it
---@field get_session_requests fun(): { successful: number, failed: number, cache_hitted: number, fcache_hitted: number } Retrieves the current session request count
---@field get_total_requests fun(): { successful: number, failed: number, cache_hitted: number, fcache_hitted: number } Retrieves the total request count from the file
---@field check_rate_limit fun(): nil Checks the current GitHub rate limit and displays a warning if low
---@field record_metrics fun(): boolean Returns state of record metrics boolean variable
---@field toogle_record_metrics fun(): boolean Toogle the state of record metrics and returns it

---@class ReqCount Counts API requests for profiling purposes
---@field successful number Stores the count of successful API requests for the current session
---@field failed number Stores the count of failed API requests for the current session
---@field cache_hitted number Stores the count of cache hits for the current session
---@field fcache_hitted number Stores the count of filecache hits for the current session

---@class RateLimits
---@field core RateLimitDetails The rate limit details for the GitHub Core API (general API requests)
---@field search RateLimitDetails The rate limit details for the GitHub Search API (search-related API requests)
---@class RateLimitDetails
---@field limit number The maximum number of requests allowed
---@field remaining number The remaining requests in the current rate limit window
---@field reset number The UNIX timestamp when the rate limit will reset



