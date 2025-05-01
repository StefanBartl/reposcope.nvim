local M = {}

M.options = {
  provider = "github",
  preferred_requesters = { "gh", "curl", "wget" },
  request_tool = "gh",
  preview_limit = 200,
  dev_mode = false
}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.options, opts or {})
end

return M
