---@class JSONParser
---@field parse fun(json_str: string): RepositoryResponse|nil Parses a JSON string and returns the parsed table
---@field read_and_parse_file fun(path: string): RepositoryResponse|nil Reads and parses a JSON file from the given path
local M = {}

local notify = require("reposcope.utils.debug").notify

---Parses a JSON string and returns the parsed table
---@param json_str string The JSON string to parse
---@return RepositoryResponse|nil
function M.parse(json_str)
  local ok, json = pcall(vim.json.decode, json_str)
  if not ok or not json.items then
    notify("[reposcope] Error parsing json response", vim.log.levels.ERROR)
    return nil
  end
  return json
end

---Read and parse JSON file
---@param path string The path to the JSON file
---@return RepositoryResponse|nil
function M.read_and_parse_file(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    notify("[reposcope] Failed to read file: " .. path, vim.log.levels.ERROR)
    return nil
  end

  local content = table.concat(lines, "\n")
  local json = M.parse(content)

  return json
end

return M
