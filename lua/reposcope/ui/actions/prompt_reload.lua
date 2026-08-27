---@module 'reposcope.ui.actions.prompt_reload'
---@brief Applies new prompt field configuration and restarts the UI.
---@description
--- This module updates the prompt field configuration dynamically and restarts the UI
--- to apply the changes. If no fields are provided, it uses the default set:
--- `keywords`, `owner`, and `language`.

local M = {}

-- Config + Core UI
local set_fields = require("reposcope.ui.prompt.prompt_config").set_fields
local notify = require("reposcope.utils.debug").notify

---@type PromptField[]
local default_fields = { "keywords", "owner", "language" }

---Applies new prompt field configuration and restarts the UI.
---@param fields string[] List of prompt fields to activate (can be empty)
---@return nil
function M.reload_prompt(fields)
  if not fields or #fields == 0 then
    fields = default_fields
    notify("[reposcope] No fields provided. Using default fields: keywords, owner, language", vim.log.levels.WARN)
  end

  set_fields(fields)

  notify("[reposcope] Prompt fields set to: " .. table.concat(fields, ", "), vim.log.levels.INFO)

  -- Restart the UI. The 80ms are not a setting and deliberately stay a
  -- literal: they exist to let `close_ui`'s window teardown finish before the
  -- reopen, i.e. to get off the current tick, not to be tuned. A config key
  -- here would invite someone to lower it to 0 and get a reopen that races
  -- the close it is waiting for.
  pcall(require("reposcope.init").close_ui)
  vim.defer_fn(function() pcall(require("reposcope.init").open_ui) end, 80)
end

return M
