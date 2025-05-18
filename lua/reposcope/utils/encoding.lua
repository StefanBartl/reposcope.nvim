---@class EncodingUtils
---@field urlencode fun(str: string): string Encodes a string for safe URL usage
---@field decode_base64 fun(encoded: string): string Decodes a Base64-encoded string (compatible with Lua)
local M = {}

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

--- Decodes a Base64-encoded string (compatible with Lua)
---@param encoded string The Base64-encoded string to decode
---@return string The decoded string
function M.decode_base64(encoded)
  -- Use Lua's native base64 decoding (more efficient)
  local decoded = vim.fn.system("echo '" .. encoded .. "' | base64 --decode")
  return decoded
end

return M
