---@class QueryBuilder
---@brief Builds GitHub-compatible search query strings from prompt input.
---@description
--- This module transforms a structured input table (from `prompt_input.collect()`)
--- into a GitHub search query string, respecting filter keys like `owner`, `language`, `topic`
--- and appending all other text as loose keywords.
---@field build fun(input: table<string, string>): string

local M = {}


-- List of known GitHub filter keys (must be formatted as `key:value`)
local FILTER_KEYS = {
  owner = "user",
  topic = "topic",
  language = "language",
  stars = "stars",
  org = "org",
}

---Builds a search query string from prompt input
---@param input table<string, string>
---@return Query
function M.build(input)
  if type(input) ~= "table" then return "" end

  local query_parts = {}
  local debug_parts = {}

  for field, value in pairs(input) do
    if type(value) == "string" and value ~= "" then
      if FILTER_KEYS[field] then
        table.insert(query_parts, field .. ":" .. value)
        debug_parts[#debug_parts+1] = string.format("filter %s=%s", field, value)
      elseif field ~= "prefix" then
        table.insert(query_parts, value)
        debug_parts[#debug_parts+1] = string.format("keyword = %s", value)
      end
    end
  end

  local final_query = table.concat(query_parts, " ")

  return final_query
end

return M
