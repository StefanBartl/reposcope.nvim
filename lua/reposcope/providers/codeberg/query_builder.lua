---@module 'reposcope.providers.codeberg.query_builder'
---@brief Builds Codeberg-compatible search query strings from prompt input.
---@description
--- Codeberg (Gitea) exposes `GET /api/v1/repos/search?q=` for repository
--- search, which — like GitLab — only supports a single plain-text substring
--- match, with no inline qualifier syntax. This builder joins every non-empty
--- prompt field value (except `prefix`) into one plain search string.

---@class CodebergQueryBuilder : QueryBuilderModule
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
