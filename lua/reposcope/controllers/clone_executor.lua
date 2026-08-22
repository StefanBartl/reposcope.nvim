---@module 'reposcope.controllers.clone_executor'
---@brief Executes shell clone commands and records metrics.
---@description
--- Executes cloning using a shell command, measures execution time,
--- and reports success/failure metrics. Also logs feedback to the user.
--- Provider-agnostic: shared by every provider's clone manager.

---@class CloneExecutor : CloneExecutorModule
local M = {}

local hrtime = vim.uv.hrtime
local notify = require("reposcope.utils.debug").notify
local metrics = require("reposcope.utils.metrics")
local safe_execute_shell_async = require("reposcope.utils.protection").safe_execute_shell_async

---@param cmd string[]
---@param uuid string
---@param repo_name string
---@param repo_url? string The repository's clone/web URL, for metrics logging
---@return nil
--- Asynchronous: `git clone` is a network operation that runs for seconds and,
--- on a large repository or a slow link, minutes. It used to go through the
--- blocking `safe_execute_shell`, freezing Neovim for the whole clone. Nothing
--- here consumed a return value -- the function only notifies and records
--- metrics -- so moving it behind a callback changes no caller.
---
--- The duration measurement still spans the real wall-clock time of the clone;
--- `start` is captured before the spawn and read in the callback.
function M.execute(cmd, uuid, repo_name, repo_url)
  local start = hrtime()

  notify("[reposcope] Cloning " .. repo_name .. "...", 2)

  safe_execute_shell_async(cmd, function(success, output)
    local duration = (hrtime() - start) / 1e6

    if success then
      if metrics.record_metrics() then
        metrics.increase_success(uuid, repo_name, "clone", "clone_repo", duration, 200, repo_url)
      end
      notify("[reposcope] Repository cloned successfully", 2)
    else
      if metrics.record_metrics() then
        metrics.increase_failed(uuid, repo_name, "clone", "clone_repo", duration, 500, output, repo_url)
      end
      notify("[reposcope] Clone failed: " .. (output or "unknown error"), 4)
    end
  end)
end

return M
