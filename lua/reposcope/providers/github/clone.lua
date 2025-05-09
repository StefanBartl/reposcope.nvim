---DEBUG:
---clone should create a folder for repo
---enter during auto-suggestion?
---hardening

local M = {}
local config = require("reposcope.config")
local repository = require("reposcope.state.repositories")
local debug = require("reposcope.utils.debug")

-- TODO: Outsource keymaps
local keymaps = require("reposcope.keymaps")

function M.init()
  debug.temprint("init clone")
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

  local dir = M.get_std_dir()
  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, { dir })
  vim.api.nvim_set_current_win(M.win)
  vim.api.nvim_win_set_cursor(M.win, {1, #dir})
  vim.defer_fn(function()
    vim.cmd("startinsert!")
  end, 10)

  M.set_clone_keymaps()
end

function M.clone_repository(dir)
  local repo = require("reposcope.state.repositories").get_selected_repo()
  local repo_url = repo.html_url
  local clone_type = config.options.clone.type


  if clone_type == "gh" then
    -- GitHub CLI Clone
    vim.fn.system(string.format("gh repo clone %s %s", repo_url, dir))
  elseif clone_type == "curl" then
    -- Download via curl (ZIP)
    local zip_url = repo_url:gsub("%.git$", "/archive/refs/heads/main.zip")
    local output_path = dir .. "/" .. repo_url:match("([^/]+)%.git") .. ".zip"
    vim.fn.system(string.format("curl -L -o %s %s", output_path, zip_url))
    vim.fn.system(string.format("unzip %s -d %s", output_path, dir))
  elseif clone_type == "wget" then
    -- Download via wget (ZIP)
    local zip_url = repo_url:gsub("%.git$", "/archive/refs/heads/main.zip")
    local output_path = dir .. "/" .. repo_url:match("([^/]+)%.git") .. ".zip"
    vim.fn.system(string.format("wget -O %s %s", output_path, zip_url))
    vim.fn.system(string.format("unzip %s -d %s", output_path, dir))
  else
    -- Standard Git Clone
    vim.fn.system(string.format("git clone %s %s", repo_url, dir))
  end

  print("Repository cloned to:", dir)
end

function M.get_std_dir()
  if config.options.clone.std_dir ~= "" and config.options.clone.std_dir then
    return config.options.clone.std_dir
  else
    local is_windows = vim.loop.os_uname().sysname:match("Windows")
    if is_windows then
      return os.getenv("USERPROFILE") or "./"
    else
      return os.getenv("HOME") or "./"
    end
  end
end

function M.set_clone_keymaps()
  if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
    vim.keymap.set("n", "<CR>", function()
      local path = vim.api.nvim_buf_get_lines(M.buf, 0, 1, false)[1]
      print("Selected Path:", path)
      M.close()
    end, { buffer = M.buf, noremap = true, silent = true })

    vim.keymap.set("i", "<CR>", function()
      local path = vim.api.nvim_buf_get_lines(M.buf, 0, 1, false)[1]
      M.clone_repository(path)
      M.close()
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
