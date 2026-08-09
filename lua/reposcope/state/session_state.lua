---@module 'reposcope.state.session_state'
---@brief Persists and restores the last search session (provider, prompt input, filter, sort).
---@description
--- A "session" here is the last search context: which provider was active,
--- which prompt fields were visible and what was typed into them, the last
--- built search query, and the last-applied filter text and sort mode. It is
--- explicitly saved/restored/cleared via `:Reposcope session save|restore|clear`
--- — nothing is persisted automatically.
---
--- The session is a single JSON file under the plugin's cache directory,
--- following the same conventions as `cache.readme_cache` (`safe_mkdir`
--- before writing, `pcall`-wrapped `io.open`/read/write/close, errors
--- reported via `utils.debug.notify`). Unlike the README cache it is a
--- single evolving file, not a keyed per-entry cache, so `save()` always
--- overwrites rather than skipping when the file already exists.

---@class SessionState : SessionStateModule
local M = {}

-- Config & Utilities
local get_session_path = require("reposcope.config").get_session_path
local safe_mkdir = require("reposcope.utils.protection").safe_mkdir
local notify = require("reposcope.utils.debug").notify
local filereadable = vim.fn.filereadable
local fnamemodify = vim.fn.fnamemodify

-- State this module reads from / writes back into
local config = require("reposcope.config")
local prompt_config = require("reposcope.ui.prompt.prompt_config")
local prompt_state = require("reposcope.state.ui.prompt_state")
local prompt_input = require("reposcope.ui.prompt.prompt_input")
local filter_repos = require("reposcope.ui.actions.filter_repos")
local sort_prompt = require("reposcope.ui.actions.sort_prompt")
local provider_controller = require("reposcope.controllers.provider_controller")

---Gathers the current search context and writes it to the session file,
--- overwriting any previous session.
---@return boolean success
function M.save()
  ---@type SessionData
  local data = {
    provider = provider_controller.get_active_provider(),
    fields = prompt_config.get_fields(),
    input = vim.deepcopy(prompt_state.input),
    query = prompt_input.get_last_query(),
    filter_text = filter_repos.get_current_filter(),
    sort_mode = sort_prompt.get_current_sort(),
  }

  local ok, encoded = pcall(vim.json.encode, data)
  if not ok then
    notify("[reposcope] Failed to encode session: " .. tostring(encoded), vim.log.levels.ERROR)
    return false
  end

  local path = get_session_path()
  safe_mkdir(fnamemodify(path, ":h"))

  local write_ok, err = pcall(function()
    local f = assert(io.open(path, "w"))
    f:write(encoded)
    f:close()
  end)

  if not write_ok then
    notify("[reposcope] Failed to write session file: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end

  notify("[reposcope] Session saved.", vim.log.levels.INFO)
  return true
end

---Reads the persisted session (if any) and re-applies it: restores the
--- prompt fields/input and active provider, re-runs the last search, then
--- reapplies the saved filter/sort once the search completes.
---@return boolean success
function M.restore()
  local path = get_session_path()
  if filereadable(path) == 0 then
    notify("[reposcope] No saved session found.", vim.log.levels.WARN)
    return false
  end

  local read_ok, content = pcall(function()
    local f = assert(io.open(path, "r"))
    local text = f:read("*a")
    f:close()
    return text
  end)

  if not read_ok then
    notify("[reposcope] Failed to read session file: " .. tostring(content), vim.log.levels.ERROR)
    return false
  end

  local decode_ok, data = pcall(vim.json.decode, content)
  if not decode_ok or type(data) ~= "table" then
    notify("[reposcope] Session file is corrupt or invalid JSON.", vim.log.levels.ERROR)
    return false
  end

  if type(data.provider) == "string" and data.provider ~= "" then config.options.provider = data.provider end

  if type(data.fields) == "table" then prompt_config.set_fields(data.fields) end

  if type(data.input) == "table" then
    for field, text in pairs(data.input) do
      prompt_state.set_field_text(field, text)
    end
  end

  local query = type(data.query) == "string" and data.query or ""
  if query == "" then
    notify("[reposcope] Session restored (no previous search to re-run).", vim.log.levels.INFO)
    return true
  end

  provider_controller.fetch_repositories_and_display(query, function()
    if type(data.filter_text) == "string" and data.filter_text ~= "" then
      filter_repos.apply_filter(data.filter_text)
    end
    if type(data.sort_mode) == "string" and data.sort_mode ~= "relevance" then
      sort_prompt.apply_sort(data.sort_mode)
    end
  end)

  notify("[reposcope] Session restored.", vim.log.levels.INFO)
  return true
end

---Removes the persisted session file, if any.
---@return boolean removed
function M.clear()
  local path = get_session_path()
  if filereadable(path) == 0 then
    notify("[reposcope] No saved session to clear.", vim.log.levels.INFO)
    return false
  end

  local ok = os.remove(path)
  if ok then
    notify("[reposcope] Session cleared.", vim.log.levels.INFO)
  else
    notify("[reposcope] Failed to remove session file: " .. path, vim.log.levels.ERROR)
  end
  return ok ~= nil
end

return M
