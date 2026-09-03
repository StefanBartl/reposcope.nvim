-- TESTS/readme_urls_spec.lua — the three providers' README URL builders.
--
-- Pure string assembly, and the only part of the README fetch a headless spec
-- can pin down: everything past it is a process spawn against a live forge.
--
-- Worth pinning because the two URLs are not interchangeable. GitHub's raw
-- host answers 404 for a private repository even when the request carries
-- credentials, so for those the API URL is not a fallback but the only path
-- that works -- which is why it asks for `/readme` (whatever the repository
-- calls its README) rather than `/contents/README.md` (that one spelling).

return function(H)
  local github = require("reposcope.providers.github.readme.readme_urls")
  local gitlab = require("reposcope.providers.gitlab.readme.readme_urls")
  local codeberg = require("reposcope.providers.codeberg.readme.readme_urls")

  -- GitHub --------------------------------------------------------------------
  do
    local urls = github.get_urls("StefanBartl", "reposcope.nvim", "main")
    H.eq(
      urls.raw,
      "https://raw.githubusercontent.com/StefanBartl/reposcope.nvim/main/README.md",
      "the raw host is addressed by branch"
    )
    H.eq(
      urls.api,
      "https://api.github.com/repos/StefanBartl/reposcope.nvim/readme?ref=main",
      "the API asks for the repository's README, whatever it is named"
    )
    H.excludes(urls.api, "contents/README.md", "not the single-spelling contents endpoint")

    -- The branch is not decoration: a repository still on `master` has to be
    -- asked about `master`, or the answer is a 404 for both URLs.
    local master = github.get_urls("StefanBartl", "Notes", "master")
    H.contains(master.raw, "/Notes/master/README.md", "the raw URL carries the branch")
    H.contains(master.api, "ref=master", "and so does the API URL")

    -- Default branch when the caller has none.
    H.contains(github.get_urls("o", "r").raw, "/o/r/main/README.md", "an absent branch defaults to main")

    -- The blob-URL form the README editor/viewer hand in.
    local blob = github.get_urls("https://github.com/o/r/blob/dev/README.md")
    H.eq(blob.raw, "https://raw.githubusercontent.com/o/r/dev/README.md", "a blob URL is taken apart")
    H.eq(blob.api, "https://api.github.com/repos/o/r/readme?ref=dev", "including its branch")
  end

  -- GitLab ---------------------------------------------------------------------
  do
    local urls = gitlab.get_urls("group", "project", "main")
    H.eq(urls.raw, "https://gitlab.com/group/project/-/raw/main/README.md", "GitLab's raw path shape")
    H.contains(urls.api, "/api/v4/projects/", "the project is addressed through the v4 API")
    H.contains(urls.api, "group%2Fproject", "with the namespaced path URL-encoded into one segment")
    H.contains(urls.api, "ref=main", "at the requested ref")
  end

  -- Codeberg -------------------------------------------------------------------
  do
    local urls = codeberg.get_urls("owner", "repo", "main")
    H.eq(urls.raw, "https://codeberg.org/owner/repo/raw/branch/main/README.md", "Gitea's raw path shape")
    H.eq(
      urls.api,
      "https://codeberg.org/api/v1/repos/owner/repo/contents/README.md?ref=main",
      "Gitea has no `/readme` endpoint, so the file is named explicitly"
    )
  end

  -- Bad input is refused, not silently turned into a broken URL -----------------
  for _, provider in ipairs({ github, gitlab, codeberg }) do
    ---@diagnostic disable-next-line: param-type-mismatch
    H.falsy(pcall(provider.get_urls, "", "repo", "main"), "an empty owner raises")
    ---@diagnostic disable-next-line: param-type-mismatch
    H.falsy(pcall(provider.get_urls, "owner", nil, "main"), "a missing repository name raises")
  end
end
