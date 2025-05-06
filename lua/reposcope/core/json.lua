local M =  {}

function M.parse(json_str)
  local ok, json = pcall(vim.json.decode, json_str)
  if not ok or not json.items then
    vim.notify("[reposcope] Error parsing json response", vim.log.levels.ERROR)
  end
  return json
end

--- Read and parse JSON file
---@param path string
---@return table|nil
function M.read_and_parse_file(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    vim.notify("[reposcope] Failed to read file: " .. path, vim.log.levels.ERROR)
    return nil
  end

  local content = table.concat(lines, "\n")
  local success, json = pcall(vim.json.decode, content)
  if not success or not json.items then
    vim.notify("[reposcope] Failed to parse JSON: " .. path, vim.log.levels.ERROR)
    return nil
  end

  return json
end

return M
