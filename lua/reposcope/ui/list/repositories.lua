local M = {}

local ui_state = require("reposcope.state.ui")
local repositories = require("reposcope.state.repositories")

-- Aktueller Zeilenindex für Highlight
M.current_line = 1
local ns_id = vim.api.nvim_create_namespace("reposcope_list_highlight")

--- Display the list of repositories
function M.display()
  local json_data = repositories.get_repositories()
  if not json_data or not json_data.items then
    vim.notify("[reposcope] No repositories loaded.", vim.log.levels.ERROR)
    return
  end

  local lines = {}
  for _, repo in ipairs(json_data.items) do
    local name = repo.name or "No name"
    local desc = repo.description or "No description"
    table.insert(lines, name .. ": " .. desc)
  end

  vim.api.nvim_buf_set_option(ui_state.buffers.list, "modifiable", true)
  vim.api.nvim_buf_set_lines(ui_state.buffers.list, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(ui_state.buffers.list, "modifiable", false)

  -- Initiales Highlight setzen
  M.update_highlight()
end

function M.configure()
  local buf = ui_state.buffers.list
  if not buf then
    vim.notify("[reposcope] List configure failed", vim.log.levels.ERROR)
    return
  end

  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "swapfile", false)

    -- Keymaps für den List-Buffer blockieren (Normalmodus)
  vim.api.nvim_buf_set_keymap(buf, "n", "h", "<Nop>", { silent = true, noremap = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "j", "<Nop>", { silent = true, noremap = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "k", "<Nop>", { silent = true, noremap = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "l", "<Nop>", { silent = true, noremap = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "i", "<Nop>", { silent = true, noremap = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "a", "<Nop>", { silent = true, noremap = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "o", "<Nop>", { silent = true, noremap = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "v", "<Nop>", { silent = true, noremap = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "<Up>", "<Nop>", { silent = true, noremap = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "<Down>", "<Nop>", { silent = true, noremap = true })
end

--- Aktualisiert das Highlight auf der aktuellen Zeile
function M.update_highlight()
  local buf = ui_state.buffers.list
  if not buf then
    vim.notify("[reposcope] Error try get buffer", vim.log.levels.ERROR)
    return
  end

  vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
  vim.api.nvim_buf_add_highlight(buf, ns_id, "ReposcopeListHighlight", M.current_line - 1, 0, -1)
end

return M
