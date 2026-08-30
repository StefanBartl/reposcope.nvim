-- TESTS/preview_image_spec.lua — reposcope.ui.preview.preview_image.find_url,
-- the pure half of the README image preview.
--
-- Only `find_url` is covered, and that is the point rather than a gap: it is
-- the function the feature's cost rests on. Detection runs against a README
-- that is already in the cache, so every repository without an image is
-- answered here, for free, with no request. Everything downstream of it
-- (`M.show`) is a network call and a terminal draw, neither of which a
-- headless spec can honestly exercise.
--
-- The fixtures are shortened real-world shapes, not invented ones: the badge
-- block is what a plugin README opens with, and "badge first, screenshot
-- later" is the case that makes naive "first image wins" wrong.

return function(H)
  local pi = require("reposcope.ui.preview.preview_image")

  -- Nothing to find -----------------------------------------------------------
  H.eq(pi.find_url(""), nil, "an empty README has no image")
  H.eq(pi.find_url("# Title\n\nProse only.\n"), nil, "and neither does prose")
  ---@diagnostic disable-next-line: param-type-mismatch
  H.eq(pi.find_url(nil), nil, "nil is answered, not raised")
  ---@diagnostic disable-next-line: param-type-mismatch
  H.eq(pi.find_url(42), nil, "so is a non-string")

  -- Badges are not images -----------------------------------------------------
  local badges = table.concat({
    "# plugin.nvim",
    "",
    "![License](https://img.shields.io/github/license/o/r)",
    "![CI](https://github.com/o/r/actions/workflows/ci.yml/badge.svg)",
    "![Coverage](https://codecov.io/gh/o/r/branch/main/graph/badge.svg)",
    "![Downloads](https://badgen.net/npm/dt/x.png)",
  }, "\n")
  H.eq(pi.find_url(badges), nil, "a README of nothing but badges yields nothing")

  -- The realistic case: badges first, the screenshot further down -------------
  local mixed = badges .. "\n\n## Demo\n\n![demo](https://example.com/assets/demo.png)\n"
  H.eq(pi.find_url(mixed), "https://example.com/assets/demo.png", "the badge block is skipped")

  -- Raster only ---------------------------------------------------------------
  H.eq(
    pi.find_url("![diagram](https://example.com/arch.svg)"),
    nil,
    "SVG is not accepted — displaying it would make ImageMagick a requirement"
  )
  for _, ext in ipairs({ "png", "jpg", "jpeg", "gif", "webp" }) do
    local url = "https://example.com/shot." .. ext
    H.eq(pi.find_url("![x](" .. url .. ")"), url, ext .. " is accepted")
  end
  H.eq(pi.find_url("![x](https://example.com/shot.PNG)"), "https://example.com/shot.PNG", "extension case is ignored")

  -- Query strings and fragments ----------------------------------------------
  H.eq(
    pi.find_url("![x](https://example.com/shot.png?raw=true)"),
    "https://example.com/shot.png?raw=true",
    "a query string does not hide the extension"
  )

  -- Inline HTML, and document order across both syntaxes ---------------------
  H.eq(
    pi.find_url('<img src="https://example.com/banner.png" width="600">'),
    "https://example.com/banner.png",
    "an HTML img is found too"
  )
  local both = '<p><img src="https://example.com/banner.png"></p>\n\n![later](https://example.com/later.png)\n'
  H.eq(pi.find_url(both), "https://example.com/banner.png", "the earlier reference wins, whichever syntax it uses")
  local md_first = '![first](https://example.com/first.png)\n\n<img src="https://example.com/second.png">\n'
  H.eq(pi.find_url(md_first), "https://example.com/first.png", "and that holds in the other direction")

  -- Relative paths are deliberately not resolved ------------------------------
  H.eq(
    pi.find_url("![demo](./assets/demo.png)"),
    nil,
    "a relative path is skipped — measured at 1 repository in 25, and that one had an absolute URL too"
  )
  H.eq(pi.find_url("![demo](assets/demo.png)"), nil, "with or without the leading dot")

  -- Not a URL scheme this can fetch ------------------------------------------
  H.eq(pi.find_url("![x](ftp://example.com/shot.png)"), nil, "only http(s) is fetchable here")

  -- clear() is a no-op without images.nvim, and must not raise ----------------
  local ok = pcall(pi.clear)
  H.ok(ok, "clear() survives images.nvim being absent")
end
