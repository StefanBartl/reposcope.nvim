---@class PreviewManager
---@brief Manages the injection of content into the preview buffer.
---@description
--- This module handles inserting content such as README data or banner text into
--- the preview buffer. It does not create the window or buffer itself, but operates
--- on existing preview buffers. It supports injecting content from cache as well as
--- raw text with specific formatting (e.g. markdown or centered banner).
---@field update_preview fun(repo_name: string): nil Updates the preview with the README of the given repository
---@field inject_content fun(buf: integer, lines: string[], filetype: string): nil Injects arbitrary content into the given buffer with the specified filetype
---@field inject_banner fun(buf: integer): nil Injects the default banner into the buffer (vertically and horizontally centered)
local M = {}

-- Utilities and Debugging
local notify = require("reposcope.utils.debug").notify
-- Application State
local ui_state = require("reposcope.state.ui.ui_state")
-- Preview-Specific Configuration and Banner
local preview_config = require("reposcope.ui.preview.preview_config")
local banner = require("reposcope.ui.preview.preview_banner").get_banner
-- Cache Access
local readme_cache = require("reposcope.cache.readme_cache")


--- Updates the preview buffer with the README of the given repository.
--- Attempts to load the README from cache and inject it into the buffer.
---@param repo_name string The repository name to fetch the README for
---@return nil
function M.update_preview(repo_name)
  if type(repo_name) ~= "string" or repo_name == "" then
    notify("[reposcope] Invalid repository name for preview update.", 4)
    return
  end

  local content = readme_cache.get_readme(repo_name)
  if not content then
    notify("[reposcope] No README content found for: " .. repo_name, 4)
    return
  end

  local buf = ui_state.buffers.preview
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
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
  if not vim.api.nvim_buf_is_valid(buf) then
    notify("[reposcope] Invalid buffer passed to inject_content", 4)
    return
  end

  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "filetype", filetype or "text")
  vim.api.nvim_buf_set_option(buf, "readonly", true)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  notify(string.format("[reposcope] Injected %s into preview buffer", filetype or "text"), 2)
end

---Injects the default banner into the preview buffer.
---@param buf integer The preview buffer handle
---@return nil
function M.inject_banner(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    notify("[reposcope] Invalid buffer passed to inject_banner", 4)
    return
  end

  local lines = banner(preview_config.width)
  M.inject_content(buf, lines, "text")
end

return M
