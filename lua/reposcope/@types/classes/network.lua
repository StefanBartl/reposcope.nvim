---@module 'reposcope.@types.classes.network'
---@brief Type definitions for network interfaces

---@class APIClientModule
---@field request fun(method: string, url: string, callback: fun(response: string|nil, error?: string|nil), headers?: table, context?: string): nil Sends an API request using HTTP module

---@class HTTPClientModule
---@field request fun(method: string, url: string, headers?: table, debug?: boolean, metrics_context?: string): nil Makes an HTTP request using the configured tool

---@class CurlRequestModule
---@field request fun(method: string, url: string, callback: fun(response: string|nil, err?: string), headers?: table<string, string>, debug?: boolean, context?: string, uuid?: string): nil Issues an asynchronous curl request with headers and metrics tracking

---@class GithubRequestModule
---@field request fun(method: string, url: string, callback: fun(response: string|nil, err?: string), headers?: table<string, string>, debug?: boolean, context?: string, uuid?: string): nil Issues an asynchronous curl request with headers and metrics tracking

---@alias RequestHeaders table<string, string>
---@alias DebugFlag boolean

---@class WgetRequestModule
---@field request fun(method: "GET", url: string, callback: fun(response: string|nil, err?: string|nil), _headers?: table<string, string>, debug?: boolean, context?: string, uuid?: string): nil

---@class NetworkRequest
---@field method string HTTP method (GET, POST, etc.)
---@field url string Target URL
---@field headers? table<string, string> Optional HTTP headers
---@field body? string Optional request body
---@field timeout? number Optional timeout in milliseconds

---@class NetworkResponse
---@field status number HTTP status code
---@field headers table<string, string> Response headers
---@field body string Response body
---@field error? string Error message if request failed

---@class RequestTool
---@field name string Tool name (gh, curl, wget)
---@field available boolean Whether the tool is available
---@field version? string Tool version if available

---@class RequestMetrics
---@field start_time number Request start timestamp
---@field end_time? number Request end timestamp
---@field duration_ms? number Request duration in milliseconds
---@field status_code? number HTTP status code
---@field error? string Error message if request failed

---@class RequestState
---@field id string Unique request identifier
---@field tool RequestTool The tool used for the request
---@field request NetworkRequest The original request
---@field response? NetworkResponse The response if available
---@field metrics RequestMetrics Request timing and status metrics
---@field cancelled boolean Whether the request was cancelled
