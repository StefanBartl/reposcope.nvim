---@module 'reposcope.providers.github.clone.clone_executor'
---@brief Executes shell clone commands and records metrics.
---@description
--- Executes cloning using a shell command, measures execution time,
--- and reports success/failure metrics. Also logs feedback to the user.

---@class GithubCloneExecutor : GithubCloneExecutorModule
local M = {}

local hrtime = vim.uv.hrtime
local notify = require("reposcope.utils.debug").notify
local metrics = require("reposcope.utils.metrics")
local safe_execute_shell = require("reposcope.utils.protection").safe_execute_shell


---@param cmd string
---@param uuid string
---@param repo_name string
---@return nil
function M.execute(cmd, uuid, repo_name)
  local start = hrtime()
  local success, output = safe_execute_shell(cmd)
  local duration = (hrtime() - start) / 1e6

  if success then
    if metrics.record_metrics() then
      metrics.increase_success(uuid, repo_name, "clone", "clone_repo", duration, 200)
    end
    notify("[reposcope] Repository cloned successfully", 2)
  else
    if metrics.record_metrics() then
      metrics.increase_failed(uuid, repo_name, "clone", "clone_repo", duration, 500, output)
    end
    notify("[reposcope] Clone failed: " .. (output or "unknown error"), 4)
  end
end

return M
