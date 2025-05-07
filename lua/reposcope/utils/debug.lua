---@class ReposcopeDebug Debug utilities for inspecting UI-related buffers and windows.
---@field notify fun(message: string, level?: number): nil Sends a notification message with an optional log level.
---@field temprint fun(message: string): nil Prints a temporary message which is marked for fast deletion
---@field test_prompt_input fun(provider: string, query: string) Manually test the input router, either "github" or other (for fallback)
---@field req_count ReqCount Stores API request count for profiling purposes
---@field increase_req fun(): nil Increases the request count for the current session and stores it in the state and file
---@field update_file_counter fun(counter_key: string): nil Increases the failed request count for the current session and stores it in the state and file
---@field get_session_requests fun(): { total: number, successful: number, failed: number } Retrieves the current session request count
---@field get_total_requests fun(): { total: number, successful: number, failed: number } Retrieves the total request count from the file
local M = {}

local config = require("reposcope.config")

---Sends a notification message with an optional log level.
---@param message string The notification message
---@param level? number Optional vim.log.levels (default: INFO)
function M.notify(message, level)
  level = level or vim.log.levels.INFO
  if config.is_dev_mode() or level >= vim.log.levels.WARN then
    vim.notify(message, level)
  end
end

---@param message string The notification message
function M.temprint(message)
  print(message)
end

---Manually test the input router with a specified provider and query.
---@param provider string The provider to test (e.g., "github")
---@param query string The search query for the provider
function M.test_prompt_input(provider, query)
  require("reposcope.config").options.provider = provider
  print(string.format("[test] Using provider: %s", provider))
  require("reposcope.ui.prompt.input").on_enter(query)
end

---@class ReqCount Counts API requests for profiling purposes
---@field requests number Stores API request count for current session
---@field successful number Stores successful request count for current session
---@field failed number Stores failed request count for current session
M.req_count = {
  requests = 0,
  successful = 0,
  failed = 0
}

---Increases the total request count for the current session and stores it in the state and file
function M.increase_req()
  M.req_count.requests = M.req_count.requests + 1
  M.update_file_counter("total_requests")
end

---Increases the successful request count for the current session and stores it in the state and file
function M.increase_success()
  M.req_count.successful = M.req_count.successful + 1
  M.update_file_counter("successful_requests")
end

---Increases the failed request count for the current session and stores it in the state and file
function M.increase_failed()
  M.req_count.failed = M.req_count.failed + 1
  M.update_file_counter("failed_requests")
end

--- Updates the specified request counter in the JSON file
---@param counter_key string The counter to update ("total_requests", "successful_requests", "failed_requests")
function M.update_file_counter(counter_key)
  local state_path = require("reposcope.config").get_state_path()
  local file_path = vim.fn.fnameescape(state_path .. "/data.json")

  -- Schedule the directory and file creation on main thread
  vim.schedule(function()
    -- Ensure directory exists
    vim.fn.mkdir(state_path, "p")

    -- Ensure file exists, create if missing
    if vim.fn.empty(vim.fn.glob(file_path)) > 0 then
      local initial_data = {
        total_requests = 0,
        successful_requests = 0,
        failed_requests = 0
      }
      initial_data[counter_key] = 1
      vim.fn.writefile({ vim.json.encode(initial_data) }, file_path)
      return
    end

    -- Read existing data
    local raw = vim.fn.readfile(file_path)
    if not raw or #raw == 0 then
      raw = { vim.json.encode({
        total_requests = 0,
        successful_requests = 0,
        failed_requests = 0
      }) }
      vim.fn.writefile(raw, file_path)
    end

    local json_data = vim.json.decode(table.concat(raw, "\n"))

    -- If file is empty or invalid, initialize it
    if not json_data then
      json_data = {
        total_requests = 0,
        successful_requests = 0,
        failed_requests = 0
      }
    end

    -- Update the specified counter
    json_data[counter_key] = (json_data[counter_key] or 0) + 1

    -- Save the updated data
    vim.fn.writefile({ vim.json.encode(json_data) }, file_path)
  end)
end

--- Retrieves the current session request counts
---@return { total: number, successful: number, failed: number }
function M.get_session_requests()
  return {
    total = M.req_count.requests,
    successful = M.req_count.successful,
    failed = M.req_count.failed
  }
end

--- Retrieves the total request counts from the file
---@return { total: number, successful: number, failed: number }
function M.get_total_requests()
  local state_path = require("reposcope.config").get_state_path()
  local file_path = vim.fn.fnameescape(state_path .. "/data.json")

  if vim.fn.filereadable(file_path) then
    local raw = vim.fn.readfile(file_path)
    local json_data = vim.json.decode(table.concat(raw, "\n"))
    return {
      total = json_data and json_data.total_requests or 0,
      successful = json_data and json_data.successful_requests or 0,
      failed = json_data and json_data.failed_requests or 0
    }
  end

  return {
    total = 0,
    successful = 0,
    failed = 0
  }
end

--- Displays the request statistics in a floating window
function M.show_stats()
  local session_stats = M.get_session_requests()
  local total_stats = M.get_total_requests()

  local lines = {
    "Reposcope Request Statistics",
    "--------------------------------",
    string.format("Session Requests: %d", session_stats.total),
    string.format(" - Successful: %d", session_stats.successful),
    string.format(" - Failed: %d", session_stats.failed),
    "",
    string.format("Total Requests: %d", total_stats.total),
    string.format(" - Successful: %d", total_stats.successful),
    string.format(" - Failed: %d", total_stats.failed),
  }

  -- Create a floating window for the stats
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local width = 40
  local height = #lines
  vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded"
  })

  -- Close the window with any key
  vim.api.nvim_buf_set_keymap(buf, "n", "q", ":bd!<CR>", { noremap = true, silent = true })
end

--- Command to show statistics directly with :ReposcopeStats
vim.api.nvim_create_user_command("ReposcopeStats", function()
  M.show_stats()
end, {})

return M
