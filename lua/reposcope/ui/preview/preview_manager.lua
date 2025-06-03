---@module 'reposcope.ui.preview.preview_manager'
---@brief Manages the injection of content into the preview buffer.
---@description
--- This module handles inserting content such as README data or banner text into
--- the preview buffer. It does not create the window or buffer itself, but operates
--- on existing preview buffers. It supports injecting content from cache as well as
--- raw text with specific formatting (e.g. markdown or centered banner).

---@class PreviewManager : PreviewManagerModule
local M = {}

-- Vim Utilities
local nvim_buf_is_valid = vim.api.nvim_buf_is_valid
local nvim_buf_set_lines = vim.api.nvim_buf_set_lines
-- Application State
local ui_state = require("reposcope.state.ui.ui_state")
-- Cache
local readme_cache_get = require("reposcope.cache.readme_cache").get
-- Preview-Specific Configuration and Banner
local preview_config = require("reposcope.ui.preview.preview_config")
local banner = require("reposcope.ui.preview.preview_banner").get_banner
-- Utilities and Debugging
local notify = require("reposcope.utils.debug").notify


--- Updates the preview buffer with the README of the given repository.
--- Attempts to load the README from cache and inject it into the buffer.
---@param repo_name string The repository name to fetch the README for
---@return nil
function M.update_preview(repo_name)
  if type(repo_name) ~= "string" or repo_name == "" then
    notify("[reposcope] Invalid repository name for preview update.", 4)
    return
  end

  local content = readme_cache_get(repo_name)
  if not content then
    notify("[reposcope] No README content found for: " .. repo_name, 4)
    return
  end

  local buf = ui_state.buffers.preview
  if not buf or not nvim_buf_is_valid(buf) then
    notify("[reposcope] Preview buffer is invalid or missing.", 4)
    return
  end

  M.inject_content(buf, vim.split(content, "\n", { plain = true }), "markdown")
end


--- Injects arbitrary content into the specified buffer and applies the given filetype.
---@param buf integer The buffer handle to inject content into
---@param lines string[] The lines to insert
---@param filetype string Filetype to apply to the buffer (e.g. "markdown", "text")
---@return nil
function M.inject_content(buf, lines, filetype)
  if not buf or not nvim_buf_is_valid(buf) then
    notify("[reposcope] Invalid buffer passed to inject_content", 4)
    return
  end

  vim.bo[buf].modifiable = true
  nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = filetype or "text"
  vim.b[buf].readonly = true
  vim.bo[buf].modifiable = false
end


---Injects the default banner into the preview buffer.
---@param buf integer The preview buffer handle
---@return nil
function M.inject_banner(buf)
  if not buf or not nvim_buf_is_valid(buf) then
    notify("[reposcope] Invalid buffer passed to inject_banner", 4)
    return
  end

  local lines = banner(preview_config.width)
  M.inject_content(buf, lines, "text")
end


---Set preview window to a blank line
---@return nil
function M.clear_preview()
  local buf = ui_state.buffers.preview
  if not buf or not nvim_buf_is_valid(buf) then
    notify("[reposcope] Cannot clear invalid preview buffer", 4)
    return
  end

  M.inject_content(buf, {""}, "text")
end

return M
