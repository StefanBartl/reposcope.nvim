--- Create the user command `:ReposcopeStart`
--- This command safely starts the Reposcope UI by calling `require("reposcope.init").open_ui()`
--- and logs an error notification if an exception occurs.
---
--- @command ReposcopeStart
vim.api.nvim_create_user_command("ReposcopeStart", function(_)
  local ok, err = pcall(function()
    require("reposcope.init").open_ui()
  end)
  if not ok then
    vim.notify("Error while opening reposcope: " .. err, vim.log.levels.ERROR)
  end
end, {
  desc = "Open Reposcope",
})

--- Create the user command `:ReposcopeClose`
--- This command safely closes the Reposcope UI by calling `require("reposcope.init").close_ui()`
--- and logs an error notification if an exception occurs.
---
--- @command ReposcopeClose
vim.api.nvim_create_user_command("ReposcopeClose", function(_)
  local ok, err = pcall(function()
    require("reposcope.init").close_ui()
  end)
  if not ok then
    vim.notify("Error while closing reposcope: " .. err, vim.log.levels.ERROR)
  end
end, {
  desc = "Close reposcope",
})
