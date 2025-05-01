if vim.health and vim.health.registry then
  vim.health.registry["reposcope"] = function()
    require("reposcope.health").check()
  end
end
