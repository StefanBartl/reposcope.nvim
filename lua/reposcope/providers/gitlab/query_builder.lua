---@module 'reposcope.providers.gitlab.query_builder'
---@brief Builds GitLab-compatible search query strings from prompt input.
---@description
--- GitLab's project search endpoint (`GET /api/v4/projects?search=`) only
--- supports a single plain-text substring match against name/path/description
--- — unlike GitHub's search API, it has no inline qualifier syntax (`owner:`,
--- `language:`, ...). This builder therefore joins every non-empty prompt
--- field value (except `prefix`) into one plain search string; field-scoped
--- filtering (owner/topic/language/stars) is not available for this provider.

---@class GitlabQueryBuilder : QueryBuilderModule
local M = {}


---Builds a plain-text search string from prompt input
---@param input table<string, string>
---@return Query
function M.build(input)
  if type(input) ~= "table" then return "" end

  local parts = {}
  for field, value in pairs(input) do
    if type(value) == "string" and value ~= "" and field ~= "prefix" then
      table.insert(parts, value)
    end
  end

  return table.concat(parts, " ")
end

return M
