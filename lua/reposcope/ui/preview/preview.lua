local M = {}
local protection = require("reposcope.utils.protection")

local lines = {
   "Ab hier Previewline",
   "Lorem preview ips",
   "Lorem pre",
   "ipsum ipsm",
   "fünfte previw"
}

M.height = protection.count_or_default(lines, 6)

return M
