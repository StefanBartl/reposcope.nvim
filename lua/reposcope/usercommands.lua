local notify = require("reposcope.utils.debug").notify

---Create the user command `:ReposcopeStart`
---This command safely starts the Reposcope UI by calling `require("reposcope.init").open_ui()`
---and logs an error notification if an exception occurs.
---
---@command ReposcopeStart
vim.api.nvim_create_user_command("ReposcopeStart", function(_)
  local ok, err = pcall(function()
    require("reposcope.init").open_ui()
  end)
  if not ok then
    notify("Error while opening reposcope: " .. err, vim.log.levels.ERROR)
  end
end, {
  desc = "Open Reposcope",
})

---Create the user command `:ReposcopeClose`
---This command safely closes the Reposcope UI by calling `require("reposcope.init").close_ui()`
---and logs an error notification if an exception occurs.
---
---@command ReposcopeClose
vim.api.nvim_create_user_command("ReposcopeClose", function(_)
  local ok, err = pcall(function()
    require("reposcope.init").close_ui()
  end)
  if not ok then
    notify("Error while closing reposcope: " .. err, vim.log.levels.ERROR)
  end
end, {
  desc = "Close reposcope",
})

---Creates the user command `:ReposcopeToggleDev`
---This command toggles the developer mode for Reposcope.
---
---@command ReposcopeToggleDev
vim.api.nvim_create_user_command("ReposcopeToggleDev", function()
  require("reposcope.utils.debug").toggle_dev_mode()
end, { desc = "Toggle Reposcope Dev Mode" })

--- Command to show statistics directly with :ReposcopeStats
vim.api.nvim_create_user_command("ReposcopeStats", function()
  require("reposcope.utils.stats").show_stats()
end, {})
