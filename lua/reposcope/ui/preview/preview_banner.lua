---@module 'reposcope.ui.preview.preview_banner'
---@brief Generates and centers the preview banner text
---@description
--- This module is responsible for generating a welcome banner to display
--- in the preview area when no repository is selected. The banner is both
--- horizontally and vertically centered based on the configured preview size.

---@class PreviewBanner : PreviewBannerModule
local M = {}

-- Text Utilities
local center_text_lines = require("reposcope.utils.text").center_text_lines


---@private
---Applies vertical centering to the banner text, maintaining a 2/3 height ratio
---@param lines string[] The lines to be vertically centered
---@return string[] Vertically centered lines
local function _apply_vertical_centering(lines)
  local total_lines = #lines
  local preview_height = require("reposcope.ui.config").height

  -- Calculate padding (1/3 top padding, 2/3 text area)
  local top_padding = math.max(0, math.floor((preview_height / 3) - (total_lines / 3)))
  local bottom_padding = math.max(0, preview_height - total_lines - top_padding)

  for _ = 1, top_padding do
    table.insert(lines, 1, "")
  end

  for _ = 1, bottom_padding do
    table.insert(lines, "")
  end

  return lines
end


---Generates a dynamically centered preview banner
---@param preview_width number The width of the preview area
---@return string[] List of centered text lines for the preview
function M.get_banner(preview_width)
  local text_lines = {
    "REPOSCOPE",
    "A versatile plugin for exploring Git-based repositories across various providers like GitHub, GitLab, Codeberg and others.",
    "",
    "If you like this plugin, consider giving it a star on GitHub.",
    "This is an open-source project, developed in my free time.",
    "",
    "Found a bug or have suggestions?",
    "Check the README.md for contribution guidelines.",
    "",
    "Thank you for using Reposcope!"
  }

  local centered_lines = center_text_lines(text_lines, preview_width)

  return _apply_vertical_centering(centered_lines)
end



return M
