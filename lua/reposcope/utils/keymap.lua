local M = {}

function M.map_over_bufs(mode, key, fn, bufs, opts)
  opts = opts or {}
  for _, buf in ipairs(bufs) do
    vim.keymap.set(mode, key, fn, vim.tbl_extend("force", opts, { buffer = buf }))
  end
end

return M
