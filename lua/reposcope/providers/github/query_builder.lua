---@class QueryBuilder
---@brief Builds GitHub-compatible search query strings from prompt input.
---@description
--- This module transforms a structured input table (from `prompt_input.collect()`)
--- into a GitHub search query string, respecting filter keys like `author`, `language`, `topic`
--- and appending all other text as loose keywords.
---@field build fun(input: table<string, string>): string

local M = {}

-- List of known GitHub filter keys (must be formatted as `key:value`)
local FILTER_KEYS = {
  author = true,
  topic = true,
  language = true,
  stars = true,
  org = true,
}

---Builds a search query string from prompt input
---@param input table<string, string>
---@return string
function M.build(input)
  if type(input) ~= "table" then return "" end

  local query_parts = {}

  for field, value in pairs(input) do
    if type(value) == "string" and value ~= "" then
      if FILTER_KEYS[field] then
        table.insert(query_parts, field .. ":" .. value)
      elseif field ~= "prefix" then
        table.insert(query_parts, value)
      end
    end
  end

  return table.concat(query_parts, " ")
end

return M
