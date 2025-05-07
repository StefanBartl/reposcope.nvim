local M = {}

local state = require("reposcope.state.repositories")
local json = require("reposcope.core.json")
local list = require("reposcope.ui.list.repositories")
local testjson = "/media/steve/Depot/MyGithub/reposcope.nvim/debug/gh_test_response.json"

--TODO: filter excklusion:
--"disabled": true,
--"visibility": "private",


---@param query string
---@param debug? boolean
function M.init(query, debug)
  if debug then
    -- Test-JSON lesen und parsen (aktueller Stand)
    state.repositories = json.read_and_parse_file(testjson)

    if state.repositories then
      list.display(state.repositories)
    else
      vim.notify("Failed to load test JSON", vim.log.levels.ERROR)
    end
  else
    -- TODO: Echte GH-API-Request hier ausführen
    -- state.repositories = <API-Response>
  end
end

---Builds curl command for GitHub repo search
---@param query string: e.g. "neovim topic:plugin"
---@return string[]: curl command
function M.build_cmd(query)
  return {
    "curl", "-s",
    "-H", "Accept: application/vnd.github+json",
    "-H", "X-GitHub-Api-Version: 2022-11-28",
    "https://api.github.com/search/repositories?q=" .. vim.fn.escape(query, " ")
  }
end

return M
