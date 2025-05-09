---DEBUG:
---clone should create a folder for repo
---enter during auto-suggestion?
---hardening

local M = {}
local config = require("reposcope.config")

-- TODO: Outsource keymaps
local keymaps = require("reposcope.keymaps")

function M.init()
  --unset_prompt_keymaps()
  M.create_win()
end

function  M.close()
  vim.api.nvim_win_close(M.win, true)
  M.unset_clone_keymaps()
 -- set_prompt_keymaps()
end

function M.create_win()
  M.buf = vim.api.nvim_create_buf(false, true)
  local width = math.min(vim.o.columns, 80)
  local heigth = 1
  local row = math.floor((vim.o.lines / 2) - (heigth / 2))
  local col = math.floor((vim.o.columns / 2) - (width / 2))
  local instruction = " Enter path for cloning "

  M.win = vim.api.nvim_open_win(M.buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = heigth,
    border = "single",
    title = instruction,
    title_pos = "center",
    style = "minimal",
  })

  local dir = config.get_clone_dir()

  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, { dir })
  vim.api.nvim_set_current_win(M.win)
  vim.api.nvim_win_set_cursor(M.win, {1, #dir})
  vim.defer_fn(function()
    vim.cmd("startinsert!")
  end, 10)

  M.set_clone_keymaps()
end

---@class CloneInfo
---@field name string The name of the repository
---@field url string The URL of the repository

---Retrieves clone information for the selected repository
---@return CloneInfo|nil clone_info The directory, name, and URL of the repository for cloning
function M.get_clone_informations()
  local repo = require("reposcope.state.repositories").get_selected_repo()
  if not repo then
    vim.notify("[reposcope] Error cloning: Repository is nil", vim.log.levels.ERROR)
    return nil
  end

  local repo_name = ""
  if repo.name and repo.name ~= "" then
    repo_name = repo.name
  else
    vim.notify("[reposcope] Error cloning: Repository name is invalid", vim.log.levels.ERROR)
    return nil
  end

  local repo_url = ""
  if repo.html_url and repo.html_url ~= "" then
    repo_url = repo.html_url
  else
    vim.notify("[reposcope] Error cloning: Repository url is invalid", vim.log.levels.ERROR)
    return nil
  end

  return { name = repo_name, url = repo_url }
end

function M.clone_repository(path)
  if not path or not vim.fn.isdirectory(path) then
    vim.notify("[reposcope] Error cloning: invalid path", vim.log.levels.ERROR)
    return
  end

  local clone_type = config.options.clone.type
  local infos = M.get_clone_informations()
  if not infos then
    vim.notify("[reposcope] Cloning aborted", vim.log.levels.ERROR)
    return
  end

  local repo_name = infos.name
  local repo_url = infos.url

  -- Normalize the path (remove trailing slashes and add one)
  path = path:gsub("/+$", "") .. "/"

  local output_dir = vim.fn.fnameescape(path .. repo_name)

  -- Ensure the target directory exists
  if not vim.fn.isdirectory(output_dir) then
    vim.fn.mkdir(output_dir, "p")
  end

  if clone_type == "gh" then
    -- GitHub CLI Clone
    vim.fn.system(string.format("gh repo clone %s %s", repo_url, output_dir))
  elseif clone_type == "curl" then
    -- Download via curl (ZIP)
    local zip_url = repo_url:gsub("%.git$", "/archive/refs/heads/main.zip")
    local output_zip = output_dir .. ".zip"
    vim.fn.system(string.format("curl -L -o %s %s", output_zip, zip_url))
    vim.notify("Repository downloaded as ZIP: " .. output_zip, vim.log.levels.INFO)
  elseif clone_type == "wget" then
    -- Download via wget (ZIP)
    local zip_url = repo_url:gsub("%.git$", "/archive/refs/heads/main.zip")
    local output_zip = output_dir .. ".zip"
    vim.fn.system(string.format("wget -O %s %s", output_zip, zip_url))
    vim.notify("Repository downloaded as ZIP: " .. output_zip, vim.log.levels.INFO)
  else
    -- Standard Git Clone
    vim.fn.system(string.format("git clone %s %s", repo_url, output_dir))
  end

  vim.notify("Repository cloned to: " .. output_dir, vim.log.levels.INFO)
  M.close()
end


function M.set_clone_keymaps()
  if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
    vim.keymap.set("n", "<CR>", function()
      local path = vim.api.nvim_buf_get_lines(M.buf, 0, 1, false)[1]
      M.clone_repository(path)
    end, { buffer = M.buf, noremap = true, silent = true })

    vim.keymap.set("i", "<CR>", function()
      local path = vim.api.nvim_buf_get_lines(M.buf, 0, 1, false)[1]
      M.clone_repository(path)
    end, { buffer = M.buf, noremap = true, silent = true })

    vim.keymap.set("n", "<C-q>", function()
      M.close()
    end, { buffer = M.buf, noremap = true, silent = true })

    vim.keymap.set("i", "<C-q>", function()
      M.close()
    end, { buffer = M.buf, noremap = true, silent = true })
  else
    vim.notify("No buffer to set keymaps", vim.log.levels.DEBUG)
  end
end

function M.unset_clone_keymaps()
  if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
    pcall(vim.keymap.del, "n", "<CR>", { buffer = M.buf })
    pcall(vim.keymap.del, "i", "<CR>", { buffer = M.buf })
    pcall(vim.keymap.del, "n", "<C-q>", { buffer = M.buf })
    pcall(vim.keymap.del, "i", "<C-q>", { buffer = M.buf })
  end
end

return M
