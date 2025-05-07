local M = {}
local readme = require("reposcope.state.readme")
local state = require("reposcope.ui.state")

--- Zeigt die README eines Repositories im Preview-Fenster an
---@param repo_name string Der Name des Repositories
function M.show_readme(repo_name)
  local content = readme.get_readme(repo_name)
  if not content then
    vim.notify("[reposcope] README not cached for: " .. repo_name, vim.log.levels.WARN)
    content = "README not cached yet."
  end

  vim.api.nvim_buf_set_option(state.buffers.preview, "modifiable", true)
  vim.api.nvim_buf_set_lines(state.buffers.preview, 0, -1, false, vim.split(content, "\n"))
  vim.api.nvim_buf_set_option(state.buffers.preview, "modifiable", false)
end

return M
