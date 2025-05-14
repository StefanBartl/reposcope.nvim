---@class ReposcopeStats
---@field show_stats fun(): nil Displays the request statistics in a floating window
---@field calculate_extended_stats fun(): number, string Calculates the average duration and most frequent query
---@field get_most_frequent_query fun(query_count: table<string, number>): string Determines the most frequent query
local M = {}

local metrics = require("reposcope.utils.metrics")
local stats_state = require("reposcope.state.popups").stats
local debug = require("reposcope.utils.debug")

--- Displays the request statistics in a floating window
function M.show_stats()
  if stats_state.win and vim.api.nvim_win_is_valid(stats_state.win) then
    vim.api.nvim_set_current_win(stats_state.win)
    return
  end

  local session_stats = metrics.get_session_requests()
  local total_stats = metrics.get_total_requests()
  local average_duration, most_frequent_query = M.calculate_extended_stats()

  local lines = {
    "Reposcope Request Statistics",
    "================================",
    "Session:",
    string.format(" - Successful requests: %d", session_stats.successful),
    string.format(" - Failed requests: %d", session_stats.failed),
    "",
    string.format(" - Cache Hits: %d", session_stats.cache_hitted),
    string.format(" - Filecache Hits: %d", session_stats.fcache_hitted),
    "",
    "--------------------------------",
    "Total:",
    string.format(" - Successful requests: %d", total_stats.successful),
    string.format(" - Failed requests: %d", total_stats.failed),
    "",
    string.format(" - Cache Hits: %d", total_stats.cache_hitted),
    string.format(" - Filecache Hits: %d", total_stats.fcache_hitted),
    "",
    "--------------------------------",
    "",
    string.format("Average Duration (ms): %.2f", average_duration),
    string.format("Most Frequent Query: %s", most_frequent_query or "N/A"),
  }

  -- Create a floating window for the stats
  stats_state.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(stats_state.buf, 0, -1, false, lines)

  local width = 50
  local height = #lines
  stats_state.win = vim.api.nvim_open_win(stats_state.buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
  })

  vim.bo[stats_state.buf].modifiable = false

  vim.keymap.set("n", "q", function()
    M.close_stats()
  end, { noremap = true, silent = true, buffer = stats_state.buf })

  vim.keymap.set("n", "<Esc>", function()
    M.close_stats()
  end, { noremap = true, silent = true, buffer = stats_state.buf })

end

function M.close_stats()
  if stats_state.buf and vim.api.nvim_buf_is_valid(stats_state.buf) then
    vim.api.nvim_buf_del_keymap(stats_state.buf, "n", "<Esc>")
    vim.api.nvim_buf_del_keymap(stats_state.buf, "n", "q")

    vim.api.nvim_buf_delete(stats_state.buf, { force = true })
    stats_state.buf = nil
  end

  if stats_state.win and vim.api.nvim_win_is_valid(stats_state.win) then
    vim.api.nvim_win_close(stats_state.win, true)
    stats_state.win = nil
  end
end

--- Calculates the average duration and most frequent query
---@return number, string The average duration and most frequent query
function M.calculate_extended_stats()
  local file_path = require("reposcope.config").get_log_path()

  if not vim.fn.filereadable(file_path) then
    debug.notify("[reposcope] File not readable or does not exist: " .. file_path, 4)
    return 0, "N/A"
  end

  local ok, raw = pcall(vim.fn.readfile, file_path)
  if not ok then
    debug.notify("[reposcope] Error reading file: " .. file_path .. " - " .. raw, 4)
    return 0, "N/A"
  end

  if not raw or #raw == 0 then
    debug.notify("[reposcope] File is empty: " .. file_path, 4)
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
