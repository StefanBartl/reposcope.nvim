---@class ListUI
---@field current_line number Current highlighted line index
---@field display fun(): nil Displays the list of repositories
---@field configure fun(): nil Configures the list buffer (no editing, restricted keymaps)
---@field clear_highlight fun(): nil Clears the highlight in the list buffer
---@field update_highlight fun(): nil Updates the highlight on the current line
local M = {}

local ui_state = require("reposcope.state.ui")
local repositories = require("reposcope.state.repositories")
local text_utils = require("reposcope.utils.text")
local ui_config = require("reposcope.ui.config")
local notify = require("reposcope.utils.debug").notify
local line_width = ui_config.width / 2

-- Current line index for highlight
M.current_line = 1
local ns_id = vim.api.nvim_create_namespace("reposcope_list_highlight")

---Display the list of repositories
function M.display()
  local json_data = repositories.get_repositories()
  if not json_data or not json_data.items then
    vim.schedule(function()
      notify("[reposcope] No repositories loaded.", 4)
    end)
    return
  end

  local lines = {}
  for _, repo in ipairs(json_data.items) do
    local owner = repo.owner and repo.owner.login or "Unknown"
    local name = repo.name or "No name"
    local desc = repo.description or "No description"
    local line = owner .. "/" .. name .. ": " .. desc
    line = text_utils.cut_text_for_line(0, line_width, line)
    table.insert(lines, line)
  end

  local buf = ui_state.buffers.list
  if not buf then
    vim.schedule(function()
      notify("[reposcope] List buffer not found.", 4)
    end)
    return
  end

  vim.schedule(function()
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)

    -- Set initial highlight
    M.update_highlight()
  end)
end

---Configures the list buffer (no editing, restricted keymaps)
function M.configure()
  local buf = ui_state.buffers.list
  if not buf then
    vim.schedule(function()
      notify("[reposcope] List configure failed", 4)
    end)
    return
  end

  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "swapfile", false)

  -- Restricted keymaps in the list buffer
  local keys = { "h", "j", "k", "l", "i", "a", "o", "v", "<Up>", "<Down>" }
  for _, key in ipairs(keys) do
    vim.api.nvim_buf_set_keymap(buf, "n", key, "<Nop>", { silent = true, noremap = true })
  end
end

---Clears the highlight in the list buffer
function M.clear_highlight()
  local buf = ui_state.buffers.list
  if not buf then return end
  vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
end

---Updates the highlight on the current line
function M.update_highlight()
  local buf = ui_state.buffers.list
  if not buf or M.current_line < 1 then
    vim.schedule(function()
      notify("[reposcope] Error: Invalid buffer or line index", 4)
    end)
    return
  end

  -- Clear old highlight
  M.clear_highlight()

  -- Apply new highlight
  vim.api.nvim_buf_add_highlight(buf, ns_id, "ReposcopeListHighlight", M.current_line - 1, 0, -1)
end

return M
