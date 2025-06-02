-- Dependecies
local nvim_create_user_command = vim.api.nvim_create_user_command
local notify = require("reposcope.utils.debug").notify
local set_fields = require("reposcope.ui.prompt.prompt_config").set_fields
local get_available_fields = require("reposcope.ui.prompt.prompt_config").get_available_fields

---This command safely starts the reposcope UI by calling `require("reposcope.init").open_ui()`
---and logs an error notification if an exception occurs.
nvim_create_user_command("ReposcopeStart", function(_)
  local ok, err = pcall(function()
    require("reposcope.init").open_ui()
  end)
  if not ok then
    notify("Error while opening reposcope: " .. err, 4)
  end
end, {
  desc = "Open Reposcope",
})

---This command safely closes the reposcope UI by calling `require("reposcope.init").close_ui()`
---and logs an error notification if an exception occurs.
nvim_create_user_command("ReposcopeClose", function(_)
  local ok, err = pcall(function()
    require("reposcope.init").close_ui()
  end)
  if not ok then
    notify("Error while closing reposcope: " .. err, 4)
  end
end, {
  desc = "Close reposcope",
})

---This command toggles the developer mode for reposcope.
nvim_create_user_command("ReposcopeToggleDev", function()
  require("reposcope.utils.debug").toggle_dev_mode()
end, { desc = "Toggle reposcope dev mode" })

---This command prints the state of developer mode for reposcope.
nvim_create_user_command("ReposcopePrintDev", function()
  print("dev_mode:", require("reposcope.utils.debug").options.dev_mode)
end, { desc = "Print reposcope dev mode" })

--- Command to show statistics directly with :ReposcopeStats
nvim_create_user_command("ReposcopeStats", function()
  require("reposcope.utils.stats").show_stats()
end, {})



nvim_create_user_command("ReposcopePromptReload", function(opts)
  local fields = opts.fargs
  if not fields or #fields == 0 then
    notify("[reposcope] Please provide one or more prompt fields", vim.log.levels.WARN)
    return
  end

  set_fields(fields)
  notify("[reposcope] Prompt fields set to: " .. table.concat(fields, ", "), vim.log.levels.INFO)
end, {
  desc = "Set and apply new prompt fields (e.g. :ReposcopePromptReload prefix keywords)",
  nargs = "+",  -- one or more arguments
  complete = function()
    return get_available_fields()
  end,
})

