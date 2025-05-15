---@class UIStart Functions to start and close the Reposcope UI
---@field setup fun(opts: table|nil): nil Initializes the UI and performs prechecks
---@field open_ui fun(): nil Opens the Reposcope UI: Captures caller position, calls the window factory functions and sets keymaps
---@field close_ui fun(): nil Closes the Reposcope UI: Set focus back to caller position, close all windows and unset keymaps
---@field setup_ui_close fun(): nil Sets up an AutoCmd for automatically closing all related UI windows (Reposcope UI)
---@field remove_ui_autocmd fun(): nil Removes the AutoCmd for automatically closing all related UI windows (Reposcope UI)
local M = {}

local config = require("reposcope.config")
local checks = require("reposcope.utils.checks")
local ui_state = require("reposcope.state.ui")
local background = require("reposcope.ui.background")
local preview = require("reposcope.ui.preview.init")
local list = require("reposcope.ui.list.init")
local list_repos = require("reposcope.ui.list.repositories")
local prompt = require("reposcope.ui.prompt.init")
local prompt_autocmds = require("reposcope.ui.prompt.autocmds")
local keymaps = require("reposcope.keymaps")

-- Ensure user commands are registered
require("reposcope.usercommands")
-- holding state for setup_ui_close and remove_ui_autocmd
local close_autocmd_id

---Initializes the Reposcope UI by applying user options and performing tool checks.
---This function should be called once during plugin setup.
---@param opts table|nil Optional configuration options to override defaults
function M.setup(opts)
  config.setup(opts or {})
  checks.resolve_request_tool()
end

---Opens the Reposcope UI.
---Captures caller position, creates background, preview, list, and prompt windows, and sets keymaps.
function M.open_ui()
  ui_state.capture_invocation_state()
  background.open_backgd()
  preview.open_preview()
  prompt.open_prompt()
  list.open_list()
  if ui_state.list_populated == true and ui_state.last_selected_line then -- If ui starts with populated list windows, fetch selected readme
    list_repos.display() -- if there are some repositories cached in RAM, show them;  REF: outsource to open list
    vim.schedule(function()
      list_repos.current_line = ui_state.last_selected_line
      require("reposcope.providers.github.readme").fetch_readme_for_selected()
    end)
  end
  keymaps.set_ui_keymaps()
  M.setup_ui_close()
end

---Closes the Reposcope UI.
---Restores the caller window, closes all Reposcope windows, and unsets keymaps.
function M.close_ui()

  -- Save state of prompt
  ui_state.last_selected_line = list_repos.current_line

  -- set focus back to caller position
  if vim.api.nvim_win_is_valid(ui_state.invocation.win) then
    vim.api.nvim_set_current_win(ui_state.invocation.win)
    vim.api.nvim_win_set_cursor(ui_state.invocation.win, {
      ui_state.invocation.cursor.row,
      ui_state.invocation.cursor.col,
    })
  end

  -- close all windows
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local ok_buf, buf = pcall(vim.api.nvim_win_get_buf, win)
    if ok_buf and vim.api.nvim_buf_is_valid(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      if name:find("^reposcope://") then
        vim.api.nvim_win_close(win, true)
      end
    end
  end

  prompt_autocmds.cleanup_autocmds()
  keymaps.unset_ui_keymaps()
  M.remove_ui_autocmd()

  vim.cmd("stopinsert")
end

-- HACK:

--- Sets up an AutoCmd for automatically closing all related UI windows (Reposcope UI).
--- The AutoCmd triggers on `QuitPre` for any window that matches the pattern `reposcope://*`.
--- If one of these windows is closed (via :q, :q!, or :wq), all related UI windows are closed.
--- The AutoCmd is stored with an ID (`close_autocmd_id`) for easy removal.
function M.setup_ui_close()
  if close_autocmd_id then
    vim.api.nvim_del_autocmd(close_autocmd_id)
  end

  close_autocmd_id = vim.api.nvim_create_autocmd("QuitPre", {
    callback = function()
      local win = vim.api.nvim_get_current_win()
      local buf = vim.api.nvim_win_get_buf(win)
      local buf_name = vim.api.nvim_buf_get_name(buf)
      if buf_name:find("^reposcope://") then
        M.close_ui()
      end
    end,
  })
end

--- Removes the AutoCmd for automatically closing all related UI windows (Reposcope UI).
--- This prevents the UI from being closed automatically when :q or :q! is used.
--- The AutoCmd ID is cleared (`close_autocmd_id = nil`) to avoid conflicts.
function M.remove_ui_autocmd()
  if close_autocmd_id then
    vim.api.nvim_del_autocmd(close_autocmd_id)
    close_autocmd_id = nil
  end
end



vim.keymap.set("n", "<leader>rs", function()
  local ok, err = pcall(function()
    require("reposcope.init").open_ui()
  end)
  if not ok then
    print("Error while opening reposcope: " .. err, 4)
  end
end, {
  desc = "Open Reposcope",
})


vim.keymap.set("n", "<leader>rc", function()
  local ok, err = pcall(function()
    require("reposcope.init").close_ui()
  end)
  if not ok then
    print("Error while closing reposcope: " .. err, 4)
  end
end, {
  desc = "close Reposcope",
})


return M
