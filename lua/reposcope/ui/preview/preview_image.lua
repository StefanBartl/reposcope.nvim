---@module 'reposcope.ui.preview.preview_image'
---@brief Draws the image a repository's README references into the preview window, on request.
---@description
--- A soft integration with [images.nvim](https://github.com/StefanBartl/images.nvim):
--- when a repository's README carries a real screenshot or demo GIF, this shows
--- it over the preview pane instead of leaving the reader with the link text.
---
--- ## Why it is a keypress and not part of the preview
---
--- The shape of this feature comes out of a measurement (2026-08-29, over 25
--- repositories: 20 widely-used Neovim plugins plus five of this author's), not
--- out of preference. Three numbers decided it:
---
--- * **8 of 25** carried a real image once badges were excluded. Two thirds of
---   previews would have nothing to show.
--- * The ones that did cost **883 ms on average and 232 kB** — worst case
---   925 kB for a single GIF. That is fine for something asked for and wrong
---   for something that fires because the selection moved.
--- * **Detection is free.** `M.find_url` reads the README that
---   `reposcope.cache.readme_cache` already holds, so answering "does this
---   repository have an image at all" costs no request and no latency. The
---   two-thirds case is therefore silent *and* instant.
---
--- The rejected half of the same measurement is worth recording here, because
--- it is the obvious thing to reach for next: GitHub's **social preview card**
--- (`opengraph.githubassets.com`) is not usable. It rate-limits unauthenticated
--- callers to 100 requests per IP and then answers `429` with
--- `Retry-After: 900` — a quarter of an hour of nothing. `readme_precache_count`
--- alone spends 5 of those per search. A cache does not rescue it either: this
--- plugin exists to find repositories nobody has seen yet, so a cache would
--- pay off on exactly the repositories whose card matters least.
---
--- ## What is *not* cached here, deliberately
---
--- Nothing. There is no third cache in this module, and that is a decision
--- rather than an omission:
---
--- * **The image file** persists in images.nvim's own SHA256-keyed cache
---   (`stdpath("cache")/images.nvim/remote`), across restarts. A second look at
---   the same repository does not download again.
--- * **The detection result** needs no cache, because it is derived from a
---   README this plugin already caches on disk. Caching "this repository has no
---   image" would cache something that is free to recompute.
--- * **A failed download** is deliberately retried on the next keypress. The
---   common cause is a transient network failure, and the user asking a second
---   time is a request to try again, not a request to be told the old answer.
---
--- ## Badges are not images
---
--- A README's first `![...]()` is almost always a shields.io badge, which is
--- both useless as a preview and usually an SVG. `BADGE_PATTERNS` filters the
--- known badge hosts, and only raster formats are accepted — the two rules
--- reinforce each other, since badges are overwhelmingly SVG and SVG display
--- would drag in ImageMagick as a hard requirement for the common path.
---
--- Relative paths (`./assets/demo.png`) are not resolved. They were measured
--- too: exactly one repository of the 25 used one, and that one also carried an
--- absolute URL. Resolving them would mean a per-provider raw-URL builder for a
--- case that does not occur.

---@class PreviewImage
local M = {}

-- Vim Utilities
local nvim_win_is_valid = vim.api.nvim_win_is_valid
-- Application State
local ui_state = require("reposcope.state.ui.ui_state")
-- Caches
local readme_cache_get = require("reposcope.cache.readme_cache").get
local get_selected = require("reposcope.cache.repository_cache").get_selected
-- Utilities and Debugging
local notify = require("reposcope.utils.debug").notify

---@private
---@internal
---Hosts and paths that serve status badges rather than content. Matched against
---the whole URL, case-insensitively.
---@type string[]
local BADGE_PATTERNS = {
  "shields%.io",
  "badgen%.net",
  "badge%.fury",
  "travis%-ci",
  "circleci",
  "codecov%.io",
  "coveralls%.io",
  "app%.netlify%.com",
  "/workflows/[^/]*badge",
  "/actions/workflows/",
  "/badge%.svg",
}

---@private
---@internal
---Raster formats a terminal can be asked to draw without a converter. SVG is
---absent on purpose: images.nvim can display it, but only by converting through
---ImageMagick, which this path deliberately does not require.
---@type table<string, boolean>
local RASTER_EXT = {
  png = true,
  jpg = true,
  jpeg = true,
  gif = true,
  webp = true,
}

---@private
---@internal
---@param url string
---@return boolean
local function is_badge(url)
  local lower = url:lower()
  for i = 1, #BADGE_PATTERNS do
    if lower:find(BADGE_PATTERNS[i]) then return true end
  end
  return false
end

---@private
---@internal
---The file extension of a URL's path component, with any query or fragment
---removed first — `demo.png?raw=true` is a PNG.
---@param url string
---@return string|nil
local function extension_of(url)
  local path_part = url:gsub("[?#].*$", "")
  local ext = path_part:match("%.([%w]+)$")
  return ext and ext:lower() or nil
end

---@private
---@internal
---Collects every capture of `pattern` together with the offset it was found at,
---so results from two different patterns can be merged back into document order.
---@param text string
---@param pattern string
---@return { pos: integer, url: string }[]
local function collect(text, pattern)
  local out = {}
  local init = 1

  while true do
    local s, e, url = text:find(pattern, init)
    if not s then break end
    out[#out + 1] = { pos = s, url = url }
    init = e + 1
  end

  return out
end

---Returns the first image in `readme` worth previewing, or `nil`.
---
---"Worth previewing" means: an absolute `http(s)` URL, in a raster format, that
---is not a status badge. Both Markdown (`![alt](url)`) and inline HTML
---(`<img src="url">`) references are considered, in the order they appear in
---the document — a README that opens with an HTML banner and mentions a
---Markdown screenshot later yields the banner.
---
---Pure: it reads the string it is given and touches nothing else. This is the
---function the whole feature's cheapness rests on, since the string is already
---in `readme_cache`.
---@param readme string The README's raw Markdown
---@return string|nil url
function M.find_url(readme)
  if type(readme) ~= "string" or readme == "" then return nil end

  local candidates = collect(readme, "!%[[^%]]*%]%((%S-)%)")
  local html = collect(readme, '<img[^>]-src="([^"]+)"')
  for i = 1, #html do
    candidates[#candidates + 1] = html[i]
  end

  table.sort(candidates, function(a, b) return a.pos < b.pos end)

  for i = 1, #candidates do
    local url = candidates[i].url
    if url:match("^https?://") and not is_badge(url) then
      local ext = extension_of(url)
      if ext and RASTER_EXT[ext] then return url end
    end
  end

  return nil
end

---Shows the selected repository's README image over the preview window.
---
---Every failure path answers. That is the opposite of the rule the *unsolicited*
---side of this feature follows — no image means no hover and no placeholder —
---and the distinction is deliberate: silence is right for UI that was never
---asked for, and wrong for a key the user just pressed.
---@return nil
function M.show()
  local repo = get_selected()
  if not repo then
    notify("[reposcope] No repository selected", 3)
    return
  end

  local owner = repo.owner and repo.owner.login
  local name = repo.name
  if type(owner) ~= "string" or type(name) ~= "string" then
    notify("[reposcope] Selected repository has no usable owner/name", 3)
    return
  end

  local readme = readme_cache_get(owner, name)
  if not readme then
    notify("[reposcope] README for " .. owner .. "/" .. name .. " is not loaded yet", 3)
    return
  end

  local url = M.find_url(readme)
  if not url then
    notify("[reposcope] " .. owner .. "/" .. name .. "'s README has no image", 2)
    return
  end

  local ok_remote, remote = pcall(require, "images.remote")
  if not ok_remote then
    notify("[reposcope] images.nvim is not installed — install it to preview README images", 3)
    return
  end

  local win = ui_state.windows.preview
  if not win or not nvim_win_is_valid(win) then
    notify("[reposcope] Preview window is not open", 3)
    return
  end

  notify("[reposcope] Loading image for " .. owner .. "/" .. name, 2)

  remote.fetch(url, function(path, err)
    if not path then
      -- images.remote's own message names the missing switch when remote
      -- images are off (`display.remote.enabled`), which is the likeliest
      -- cause here — pass it through rather than paraphrase it.
      notify("[reposcope] " .. tostring(err), 3)
      return
    end

    -- The download is asynchronous and the UI is not: by the time the bytes
    -- arrive the user may have closed reposcope, or moved to another
    -- repository. Re-read the window rather than trusting the one captured
    -- above, and draw nothing if it is gone.
    local target = ui_state.windows.preview
    if not target or not nvim_win_is_valid(target) then return end

    local ok_browse, browse = pcall(require, "images.browse")
    if not ok_browse then
      notify("[reposcope] images.browse is unavailable", 3)
      return
    end

    if not browse.draw_in_window(path, target) then
      notify("[reposcope] The image cannot be drawn in this terminal (see :Image check)", 3)
    end
  end)
end

---Removes a drawn image from the screen.
---
---A terminal image is painted *over* the grid rather than into a buffer, so it
---survives everything Neovim does to the window underneath it — including the
---preview being refilled with a different repository's README. Anything that
---changes what the preview shows has to call this.
---
---A no-op when images.nvim is absent, which is the normal case.
---@return nil
function M.clear()
  local ok, images = pcall(require, "images")
  if not ok then return end
  pcall(images.clear)
end

return M
