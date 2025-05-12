---@class ReposcopeStats
---@field show_stats fun(): nil Displays the request statistics in a floating window
---@field calculate_extended_stats fun(): number, string Calculates the average duration and most frequent query
---@field get_most_frequent_query fun(query_count: table<string, number>): string Determines the most frequent query
local M = {}
local metrics = require("reposcope.utils.metrics")

--- Displays the request statistics in a floating window
function M.show_stats()
  local session_stats = metrics.get_session_requests()
  local total_stats = metrics.get_total_requests()
  local average_duration, most_frequent_query = M.calculate_extended_stats()

  local lines = {
    "Reposcope Request Statistics",
    "================================",
    string.format("Session Requests: %d", session_stats.total),
    string.format(" - Successful: %d", session_stats.successful),
    string.format(" - Failed: %d", session_stats.failed),
    "",
    string.format(" - Session Cache Hits: %d", session_stats.cache_hitted),
    "--------------------------------",
    "",
    string.format("Total Requests: %d", total_stats.total),
    string.format(" - Successful: %d", total_stats.successful),
    string.format(" - Failed: %d", total_stats.failed),
    "",
    string.format(" - Total Cache Hits: %d", total_stats.cache_hitted),
    "--------------------------------",
    "",
    string.format("Average Duration (ms): %.2f", average_duration),
    string.format("Most Frequent Query: %s", most_frequent_query or "N/A"),
  }

  -- Create a floating window for the stats
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local width = 50
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

--- Calculates the average duration and most frequent query
---@return number, string The average duration and most frequent query
function M.calculate_extended_stats()
  local file_path = require("reposcope.config").get_log_path()

  if not vim.fn.filereadable(file_path) then
    return 0, "N/A"
  end

  local raw = vim.fn.readfile(file_path)
  if not raw or #raw == 0 then
    return 0, "N/A"
  end

  local logs = vim.json.decode(table.concat(raw, "\n")) or {}
  local total_duration = 0
  local query_count = {}
  local success_count = 0

  for _, log in pairs(logs) do
    if log.type == "api_success" then
      if log.duration_ms then
        total_duration = total_duration + log.duration_ms
      end
      success_count = success_count + 1
    end

    if log.query then
      query_count[log.query] = (query_count[log.query] or 0) + 1
    end
  end

  local average_duration = success_count > 0 and (total_duration / success_count) or 0
  local most_frequent_query = M.get_most_frequent_query(query_count)

  return average_duration, most_frequent_query
end

--- Determines the most frequent query from a query count table
---@param query_count table<string, number> Table of query counts
---@return string The most frequent query
function M.get_most_frequent_query(query_count)
  local most_frequent_query = nil
  local max_count = 0

  for query, count in pairs(query_count) do
    if count > max_count then
      max_count = count
      most_frequent_query = query
    end
  end

  return most_frequent_query or "N/A"
end

return M
