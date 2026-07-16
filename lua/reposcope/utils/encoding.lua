---@module 'reposcope.utils.encoding'
---@brief Utility functions for string encoding (URL, Base64).

---@class EncodingUtils : EncodingUtilsModule
local M = {}

--- Encodes a string for safe URL usage (percent-encoding). Delegates the
--- percent-encoding itself to lib.lua.strings.encoding.url_encode.
---@param str string The string to be URL-encoded
---@return string The URL-encoded string
function M.urlencode(str)
  -- Replace newline characters with CRLF for URL encoding
  local crlf_encoded = str:gsub("\n", "\r\n")
  return require("lib.lua.strings.encoding").url_encode(crlf_encoded)
end

---Decodes a Base64-encoded string. Delegates to lib.lua.strings.encoding
---(pure Lua, no shell-out, works identically on every platform).
---@param encoded string The Base64-encoded string to decode
---@return string The decoded string
function M.decode_base64(encoded)
  return require("lib.lua.strings.encoding").base64_decode(encoded)
end

return M
