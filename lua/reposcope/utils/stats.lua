---@module 'reposcope.ui.stats'
---@brief Displays and analyzes API request statistics in a floating UI window.
---@description
--- This module renders session and total API usage statistics such as successful requests,
--- cache hits, average durations, and most frequent queries in a floating popup.

---@class Stats : StatsModule
local M = {}

-- Vim Utilities
local fn = vim.fn
local api = vim.api
local filereadable = fn.filereadable
local readfile = fn.readfile
local buf_is_valid = api.nvim_buf_is_valid
local buf_delete = api.nvim_buf_delete
local buf_set_lines = api.nvim_buf_set_lines
local win_is_valid = api.nvim_win_is_valid
local win_set_current = api.nvim_set_current_win
local open_win = api.nvim_open_win
local buf_del_keymap = api.nvim_buf_del_keymap
local set_keymap = vim.keymap.set

-- Metrics Management (Tracking Performance and Usage Statistics)
local metrics = require("reposcope.utils.metrics")
-- State Management (Stats Popup)
local stats_state = require("reposcope.state.popups.stats_popup").stats
-- Configuration & Debugging
local get_option = require("reposcope.config").get_option
local notify = require("reposcope.utils.debug").notify


---Displays the request statistics in a floating window.
---Creates a new window if none exists, or focuses the existing one.
---@return nil
function M.show_stats()
  if stats_state.win and win_is_valid(stats_state.win) then
    win_set_current(stats_state.win)
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

  stats_state.buf = require("reposcope.utils.protection").create_named_buffer("reposcope://stats")
  buf_set_lines(stats_state.buf, 0, -1, false, lines)

  local width = 50
  local height = #lines
  stats_state.win = open_win(stats_state.buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
  })

  vim.bo[stats_state.buf].modifiable = false

  set_keymap("n", "q", function() M.close_stats() end, { noremap = true, silent = true, buffer = stats_state.buf })
  set_keymap("n", "<Esc>", function() M.close_stats() end, { noremap = true, silent = true, buffer = stats_state.buf })
end


---Closes the statistics popup window and removes associated keymaps.
---@return nil
function M.close_stats()
  if stats_state.buf and buf_is_valid(stats_state.buf) then
    buf_del_keymap(stats_state.buf, "n", "<Esc>")
    buf_del_keymap(stats_state.buf, "n", "q")
    buf_delete(stats_state.buf, { force = true })
    stats_state.buf = nil
  end

  if stats_state.win and win_is_valid(stats_state.win) then
    api.nvim_win_close(stats_state.win, true)
    stats_state.win = nil
  end
end


---Calculates the average request duration and most frequent query from logs.
---@return number average_duration The average request duration in milliseconds
---@return string most_frequent_query The most frequently used search query
function M.calculate_extended_stats()
  local file_path = get_option("logfile_path")

  if not file_path or not filereadable(file_path) then
    notify("[reposcope] File not readable or does not exist: " .. file_path, 4)
    return 0, "N/A"
  end

  local ok, raw = pcall(readfile, file_path)
  if not ok then
    notify("[reposcope] Error reading file: " .. file_path .. " - " .. raw, 4)
    return 0, "N/A"
  end

  if not raw or #raw == 0 then
    notify("[reposcope] File is empty: " .. file_path, 4)
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


---Finds the most frequently used query from a table of query counts.
---@param query_count table<string, number> Map of query strings to occurrence count
---@return string most_frequent_query The most frequent query or "N/A"
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

