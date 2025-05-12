---DEBUG:
---enter during auto-suggestion?
---hardening

---@desc forward decalarations
local create_win, get_clone_informations

local M = {}

local config = require("reposcope.config")
local state = require("reposcope.state.popups")

function M.init()
  require("reposcope.keymaps").unset_prompt_keymaps()
  create_win()
end

function  M.close()
  vim.api.nvim_win_close(state.clone.win, true)
  require("reposcope.keymaps").unset_clone_keymaps()
  require("reposcope.keymaps").set_prompt_keymaps()
end

---@private
function create_win()
  state.clone.buf = vim.api.nvim_create_buf(false, true)
  local width = math.min(vim.o.columns, 80)
  local heigth = 1
  local row = math.floor((vim.o.lines / 2) - (heigth / 2))
  local col = math.floor((vim.o.columns / 2) - (width / 2))

  state.clone.win = vim.api.nvim_open_win(state.clone.buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = heigth,
    border = "single",
    title = " Enter path for cloning ",
    title_pos = "center",
    style = "minimal",
  })

  local dir = config.get_clone_dir()

  vim.api.nvim_buf_set_lines(state.clone.buf, 0, -1, false, { dir })
  vim.api.nvim_set_current_win(state.clone.win)
  vim.api.nvim_win_set_cursor(state.clone.win, {1, #dir})
  vim.defer_fn(function()
    vim.cmd("startinsert!")
  end, 10)

  require("reposcope.keymaps").set_clone_keymaps()
end

---@class CloneInfo
---@field name string The name of the repository
---@field url string The URL of the repository

---Retrieves clone information for the selected repository
---@private
---@return CloneInfo|nil clone_info The directory, name, and URL of the repository for cloning
function get_clone_informations()
  local repo = require("reposcope.state.repositories").get_selected_repo()
  if not repo then
    vim.notify("[reposcope] Error cloning: Repository is nil", 4)
    return nil
  end

  local repo_name = ""
  if repo.name and repo.name ~= "" then
    repo_name = repo.name
  else
    vim.notify("[reposcope] Error cloning: Repository name is invalid", 4)
    return nil
  end

  local repo_url = ""
  if repo.html_url and repo.html_url ~= "" then
    repo_url = repo.html_url
  else
    vim.notify("[reposcope] Error cloning: Repository url is invalid", 4)
    return nil
  end

  return { name = repo_name, url = repo_url }
end

--REF: pcall()
local metrics = require("reposcope.utils.metrics")

--- Clones a GitHub repository using various methods (gh, curl, wget, git)
---@param path string The local path where the repository should be cloned
function M.clone_repository(path)
  if not path or not vim.fn.isdirectory(path) then
    vim.notify("[reposcope] Error cloning: invalid path", 4)
    return
  end

  local clone_type = config.options.clone.type
  local infos = get_clone_informations()
  if not infos then
    vim.notify("[reposcope] Cloning aborted", 4)
    return
  end

  local repo_name = infos.name
  local repo_url = infos.url
  local uuid = metrics.generate_uuid()
  local start_time = vim.loop.hrtime()
  local source = "clone_repo"
  local query = repo_name

  -- Normalize the path (remove trailing slashes and add one)
  path = path:gsub("/+$", "") .. "/"
  local output_dir = vim.fn.fnameescape(path .. repo_name)

  if not vim.fn.isdirectory(output_dir) then
    vim.fn.mkdir(output_dir, "p")
  end

  local success = false
  local error_msg = ""

  -- Clone based on selected method
  if clone_type == "gh" then
    vim.fn.system(string.format("gh repo clone %s %s", repo_url, output_dir))
    success = vim.v.shell_error == 0
    error_msg = "GitHub CLI clone failed."
  elseif clone_type == "curl" then
    local zip_url = repo_url:gsub("%.git$", "/archive/refs/heads/main.zip")
    local output_zip = output_dir .. ".zip"
    vim.fn.system(string.format("curl -L -o %s %s", output_zip, zip_url))
    success = vim.v.shell_error == 0
    error_msg = "Curl download failed."
  elseif clone_type == "wget" then
    local zip_url = repo_url:gsub("%.git$", "/archive/refs/heads/main.zip")
    local output_zip = output_dir .. ".zip"
    vim.fn.system(string.format("wget -O %s %s", output_zip, zip_url))
    success = vim.v.shell_error == 0
    error_msg = "Wget download failed."
  else
    vim.fn.system(string.format(("git clone %s %s"):format(), repo_url, output_dir))
    success = vim.v.shell_error == 0
    error_msg = "Git clone failed."
  end

  local duration_ms = (vim.loop.hrtime() - start_time) / 1e6 -- Duration in milliseconds

  if success then
    metrics.increase_success(uuid, query, source, "clone_repository", duration_ms, 200)
    vim.notify("Repository cloned to: " .. output_dir, 2)
  else
    local error_msg = string.format("Failed to clone repository: %s", repo_url)
    metrics.increase_failed(uuid, query, source, "clone_repository", duration_ms, 500, error_msg)
    vim.notify(error_msg, 4)
  end

  M.close()
end

return M
