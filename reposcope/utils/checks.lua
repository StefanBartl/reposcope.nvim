local config = require("reposcope.config")

local M = {}

function M.has_binary(name)
  return vim.fn.executable(name) == 1
end

function M.first_available(binaries)
  for _, bin in ipairs(binaries) do
    if M.has_binary(bin) then return bin end
  end
  return nil
end

function M.resolve_request_tool(requesters)
  requesters = requesters or config.options.preferred_requesters or { "gh", "curl", "wget" }

  local req_tool = M.first_available(requesters)
  if not req_tool then
    vim.notify("[reposcope.nvim]: no request tool available", vim.log.levels.ERROR)
  else
    config.options.request_tool = req_tool
end

end

function M.has_env(name)
  return vim.env[name] and #vim.env[name] > 0 then
end

return M
