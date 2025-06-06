---@module 'reposcope.@types.classes.utils'
---@brief Class definitions for all utility modules in `reposcope.utils`

---@class ErrorUtilsModule
---@field safe_call fun(fn: fun(...): any, ...: any): Result Wraps a function call in a standardized error handling pattern
---@field new_error fun(type: ErrorType, message: string, details?: table): Error Creates a new error object

---@class Result
---@field ok boolean Whether the operation succeeded
---@field result any The result of the operation if successful
---@field err string|nil The error message if the operation failed

---@class Error
---@field type ErrorType
---@field message string
---@field details? table

---@class ReposcopeChecksModule Utility functions for checking environment conditions and available binaries.
---@field has_binary fun(name: string): boolean Returns true if the given binary is executable on the system.
---@field first_available fun(binaries: string[]): string|nil Returns the first available binary from a list or nil if none found.
---@field resolve_request_tool fun(requesters?: string[]): nil Selects the preferred available request tool and sets it in config.
---@field has_env fun(name: string): boolean Returns true if the given environment variable is set and non-empty.

---@class CoreUtilsModule
---@field tbl_find fun(tbl: table, value: any): integer|nil Searches for a value in the table and returns its index
---@field tbl_islist fun(t: any): boolean Checks if a table is a proper list: integer keys 1..#t without gaps or non-integer keys.
---@field flatten_table fun(input: table, result?: table): table Recursively flattens a nested table into a flat list
---@field dedupe_list fun(list: string[]): string[] Returns a new list with all duplicates removed (preserving order)
---@field put_to_front_if_present fun(list: string[], value: string): string[] Ensures that the given value appears first in the list if present
---@field ensure_string fun(val: string): string Ensures that a given argument 'val' is from type string, else returns empty string
---@field generate_uuid fun(): string  Creates a UUID based on actual timestamp

---@class DebugUtilsModule Debug utilities for inspecting UI-related buffers and windows.
---@field options DebugOptions Configurations options for debugging of reposcope
---@field is_dev_mode fun(): boolean Checks if developer mode is enabled
---@field set_dev_mode fun(value: boolean): nil Sets the debug mode to a specific value
---@field toggle_dev_mode fun(): nil Toggle dev mode (standard: false)
---@field notify fun(message: string, level?: number): nil Sends a notification message with an optional log level.
---@field debugf fun(msg: string, level?: number, log_level?: number, _schedule?: boolean): nil Enhanced debugging function for logging
---@field print_win_buf_state fun(): nil Prints actual state for debugging to the console

---@class EncodingUtilsModule
---@field urlencode fun(str: string): string Encodes a string for safe URL usage
---@field decode_base64 fun(encoded: string): string Decodes a Base64-encoded string (compatible with Lua)

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

---@class OSUtilsModule
---@field open_url fun(url: string): nil Opens the given URL in the system's default web browser

---@class UtilsProtectionModule
---@brief Utility functions related to value normalization, path validation, and buffer management
---@field debounce fun(fn: fun(...: any): any, delay_ms: number): fun(...: any): any Ensures that rapid repeated invocations will only trigger the final call after the delay interval.
---@field debounce_with_counter fun(fn: fun(...: any): any, delay_ms: number): fun(...: any): any Ensures that rapid repeated invocations will only trigger the final call after the delay interval.
---@field count_or_default fun(val: table|number|string, default: number): number Returns the item count if `val` is a table, the number if `val` is a number, or `default` otherwise
---@field create_named_buffer fun(name: string): integer|nil Creates a named scratch buffer, replacing any existing one with the same name
---@field is_valid_filename fun(filename: string|nil): boolean, string Returns true and empty string if valid, false and error message otherwise
---@field is_valid_path fun(path: string, nec_filename?: boolean): boolean Validates if a given path or optional filepath is a valid and writable file path
---@field safe_mkdir fun(path: string): boolean Safely creates a directory (including parent directories)
---@field is_dir_writeable fun(path: string): boolean Checks if a directory is writable by attempting a test write
---@field safe_execute_shell fun(command: string): boolean, string Executes a shell command safely and returns the success status and output

---@class StatsModule
---@field show_stats fun(): nil Opens a floating stats window with session and total statistics
---@field close_stats fun(): nil Closes the stats popup and cleans up associated resources
---@field calculate_extended_stats fun(): (number, string) Computes the average duration and most frequent query from log
---@field get_most_frequent_query fun(query_count: table<string, number>): string Returns the most frequent query from a query count map

---@class TextUtilsModule
---@field center_text fun(text: string, width: number): string[] Centers given text input and returns it, splitting lines without breaking words
---@field center_text_lines fun(lines: string[], width: number): string[] Centers an array of text lines within a specified width
---@field cut_text_for_line fun(offset: number, width: number, input: string): string Cuts given input to fit in 1 row and postfix it with '...'
---@field gen_padded_lines fun(height: number, content: string|string[]): string[] Pads or trims content to a specific number of lines
