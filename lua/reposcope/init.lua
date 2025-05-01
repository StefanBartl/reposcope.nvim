local config = require("reposcope.config")
local checks = require("reposcope.utils.checks")

local M = {}

function M.setup(opts)
  config.setup(opts or {})
  checks.resolve_request_tool()
end

return M
