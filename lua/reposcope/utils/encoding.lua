---@module 'reposcope.utils.encoding'
---@brief Utility functions for string encoding (URL, Base64).

---@class EncodingUtils : EncodingUtilsModule
local M = {}

local bit = require("bit")
local lshift, rshift, bor, band = bit.lshift, bit.rshift, bit.bor, bit.band

local base64_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

---@private
---Reverse lookup table: base64 character -> its 6-bit index
local base64_index = {}
for i = 1, #base64_chars do
  base64_index[base64_chars:sub(i, i)] = i - 1
end

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


---Decodes a Base64-encoded string. Pure-Lua implementation (no shell-out),
---so it works identically on every platform, including Windows.
---@param encoded string The Base64-encoded string to decode
---@return string The decoded string
function M.decode_base64(encoded)
  encoded = encoded:gsub("[^" .. base64_chars .. "=]", "")

  local decoded = {}
  local bits, value = 0, 0

  for i = 1, #encoded do
    local char = encoded:sub(i, i)
    if char ~= "=" then
      value = bor(lshift(value, 6), base64_index[char])
      bits = bits + 6

      if bits >= 8 then
        bits = bits - 8
        decoded[#decoded + 1] = string.char(band(rshift(value, bits), 0xFF))
      end
    end
  end

  return table.concat(decoded)
end

return M
