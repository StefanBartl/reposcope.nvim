local notify = require("reposcope.utils.debug").notify

---This command safely starts the reposcope UI by calling `require("reposcope.init").open_ui()`
---and logs an error notification if an exception occurs.
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

---This command safely closes the reposcope UI by calling `require("reposcope.init").close_ui()`
---and logs an error notification if an exception occurs.
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

---This command toggles the developer mode for reposcope.
vim.api.nvim_create_user_command("ReposcopeToggleDev", function()
  require("reposcope.utils.debug").toggle_dev_mode()
end, { desc = "Toggle reposcope dev mode" })

---This command prints the state of developer mode for reposcope.
vim.api.nvim_create_user_command("ReposcopePrintDev", function()
  print("dev_mode:", require("reposcope.utils.debug").options.dev_mode)
end, { desc = "Print reposcope dev mode" })

--- Command to show statistics directly with :ReposcopeStats
vim.api.nvim_create_user_command("ReposcopeStats", function()
  require("reposcope.utils.stats").show_stats()
end, {})
