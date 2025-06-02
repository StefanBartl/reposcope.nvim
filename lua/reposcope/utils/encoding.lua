---@module 'reposcope.utils.encoding'
---@brief Utility functions for string encoding (URL, Base64).

---@class EncodingUtils : EncodingUtilsModule
local M = {}

local system = vim.fn.system

--- Encodes a string for safe URL usage (percent-encoding)
---@param str string The string to be URL-encoded
---@return string The URL-encoded string
function M.urlencode(str)
  -- Replace newline characters with CRLF for URL encoding
  local crlf_encoded = str:gsub("\n", "\r\n")

  -- Convert all other special characters to percent-encoded form
  local url_encoded = crlf_encoded:gsub("([^%w%-_.~])", function(char)
    return string.format("%%%02X", string.byte(char))
  end)

  return url_encoded
end


---Decodes a Base64-encoded string compatible with Lua
---@param encoded string The Base64-encoded string to decode
---@return string The decoded string
function M.decode_base64(encoded)
  -- Use Lua's native base64 decoding
  local decoded = system("echo '" .. encoded .. "' | base64 --decode")
  return decoded
end

return M
