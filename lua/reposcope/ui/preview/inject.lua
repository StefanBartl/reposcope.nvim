---@class UIPreview
---@field show_readme fun(repo_name: string, force_markdown?: boolean): nil Displays the README of a repository in the preview window
local M = {}

local readme = require("reposcope.state.readme")
local state = require("reposcope.state.ui")
local notify = require("reposcope.utils.debug").notify

---Displays the README of a repository in the preview window
---@param repo_name string The name of the repository
---@param force_markdown? boolean If true, forces Markdown highlighting
function M.show_readme(repo_name, force_markdown)
  local content = readme.get_readme(repo_name)
  if not content then
    notify("[reposcope] README not cached for: " .. repo_name, 3)
    content = "README not cached yet."
  end

  local buf = state.buffers.preview
  if not buf then
    notify("[reposcope] Preview buffer not found.", 4)
    return
  end

  -- Use vim.schedule to avoid fast event context issue
  vim.schedule(function()
    -- Apply content to the preview buffer
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
    vim.api.nvim_buf_set_option(buf, "readonly", true)

    -- Set filetype to markdown only if content is Markdown or forced
    if force_markdown or content:match("^#") or content:match("```") then
      vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
    else
      vim.api.nvim_buf_set_option(buf, "filetype", "text")
    end
  end)
end

return M
