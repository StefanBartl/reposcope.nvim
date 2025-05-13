---@class DefaultPreviewBanner
---@field get_banner fun(preview_width: number): string[] Function to dynamically generate a default, centered preview banner
local M = {}

local text = require("reposcope.utils.text")

---Generates a dynamically centered preview banner
---@param preview_width number The width of the preview area
---@return string[] List of centered text lines for the preview
function M.get_banner(preview_width)
  -- Core banner text content
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

  -- Center each line and collect results
  local centered_lines = text.center_text_lines(text_lines, preview_width)

  -- Apply vertical centering (2/3 height, 1/3 top padding)
  return M.apply_vertical_centering(centered_lines)
end


---Applies vertical centering to the banner text, maintaining a 2/3 height ratio
---@param lines string[] The lines to be vertically centered
---@return string[] Vertically centered lines
function M.apply_vertical_centering(lines)
  local total_lines = #lines
  local preview_height = require("reposcope.ui.config").height

  -- Calculate padding (1/3 top padding, 2/3 text area)
  local top_padding = math.max(0, math.floor((preview_height / 3) - (total_lines / 3)))
  local bottom_padding = math.max(0, preview_height - total_lines - top_padding)

  -- Add top padding
  for _ = 1, top_padding do
    table.insert(lines, 1, "")
  end

  -- Add bottom padding
  for _ = 1, bottom_padding do
    table.insert(lines, "")
  end

  return lines
end

return M

