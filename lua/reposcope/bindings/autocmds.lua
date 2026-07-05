---@module 'reposcope.bindings.autocmds'
---@brief Top-level autocommands for the Reposcope UI lifecycle
---@description
--- Registers the `QuitPre` autocmd that closes the whole Reposcope UI when one
--- of its windows is closed directly (`:q`, `:q!`, `:wq`). Colocated here with
--- the other binding registrations (keymaps, user commands); UI-internal
--- autocmds (e.g. prompt cursor locking) remain next to the module they serve.

local M = {}

-- Vim Utilities
local nvim_get_current_win = vim.api.nvim_get_current_win
local nvim_win_get_buf = vim.api.nvim_win_get_buf
local nvim_buf_get_name = vim.api.nvim_buf_get_name
local nvim_create_autocmd = vim.api.nvim_create_autocmd
local nvim_del_autocmd = vim.api.nvim_del_autocmd

---@type integer|nil
local close_autocmd_id

---Sets up an AutoCmd for automatically closing all related UI windows (Reposcope UI).
--- The AutoCmd triggers on `QuitPre` for any window that matches the pattern `reposcope://*`.
--- If one of these windows is closed (via :q, :q!, or :wq), `on_close` is invoked.
---@param on_close fun(): nil Callback that closes the Reposcope UI
---@return nil
function M.setup_ui_close(on_close)
  if close_autocmd_id then
    nvim_del_autocmd(close_autocmd_id)
  end

  close_autocmd_id = nvim_create_autocmd("QuitPre", {
    callback = function()
      local win = nvim_get_current_win()
      local buf = nvim_win_get_buf(win)
      local buf_name = nvim_buf_get_name(buf)
      if buf_name:find("^reposcope://") then
        on_close()
      end
    end,
  })
end

---Removes the AutoCmd for automatically closing all related UI windows (Reposcope UI).
---@return nil
function M.remove_ui_autocmd()
  if close_autocmd_id then
    nvim_del_autocmd(close_autocmd_id)
    close_autocmd_id = nil
  end
end

return M
