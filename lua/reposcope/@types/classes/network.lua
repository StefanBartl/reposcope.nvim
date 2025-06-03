---@module 'reposcope.@types.classes.network'
---@brief Type definitions for network interfaces

---@class APIModule
---@field request fun(method: string, url: string, callback: fun(response: string|nil, error?: string|nil), headers?: table, context?: string): nil Sends an API request using HTTP module

---@class CurlRequestModule
---@field request fun(method: string, url: string, callback: fun(response: string|nil, err?: string), headers?: table<string, string>, debug?: boolean, context?: string, uuid?: string): nil Issues an asynchronous curl request with headers and metrics tracking

---@class GithubRequestModule
---@field request fun(method: string, url: string, callback: fun(response: string|nil, err?: string), headers?: table<string, string>, debug?: boolean, context?: string, uuid?: string): nil Issues an asynchronous curl request with headers and metrics tracking

---@alias RequestHeaders table<string, string>
---@alias DebugFlag boolean

---@class WgetRequestModule
---@field request fun(method: "GET", url: string, callback: fun(response: string|nil, err?: string|nil), _headers?: table<string, string>, debug?: boolean, context?: string, uuid?: string): nil
