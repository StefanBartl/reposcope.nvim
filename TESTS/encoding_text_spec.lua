-- Test code: when something here comes back nil -- a `pcall(require, ...)`,
-- a fixture read, a uv handle -- this file must crash and name it. The nil
-- guards LuaLS asks for below would hide the very failure it exists to report.
---@diagnostic disable: need-check-nil
-- TESTS/encoding_text_spec.lua — `utils.encoding` (what goes into a query
-- string and what comes out of a base64 README) and `utils.text` (the line
-- shaping every window in the plugin runs its content through).

return function(H)
  ---------------------------------------------------------------------------
  -- encoding
  ---------------------------------------------------------------------------
  do
    local encoding = require("reposcope.utils.encoding")

    H.eq(encoding.urlencode("nvim"), "nvim", "an unreserved string is unchanged")
    H.eq(encoding.urlencode(""), "", "so is an empty one")
    H.eq(encoding.urlencode("neovim plugin"), "neovim%20plugin", "a space is percent-encoded")

    -- The qualifier syntax GitHub search uses (`user:me`, `stars:>100`) must
    -- survive as data, not be interpreted as URL structure.
    H.contains(encoding.urlencode("user:me"), "%3A", "a colon is encoded")
    H.contains(encoding.urlencode("stars:>100"), "%3E", "and so is a comparison operator")
    H.contains(encoding.urlencode("a&b=c"), "%26", "an ampersand cannot start a new query parameter")
    H.contains(encoding.urlencode("a&b=c"), "%3D", "and an equals sign cannot start a new value")
    H.contains(encoding.urlencode("100%"), "%25", "a literal percent is escaped rather than read as an escape")

    -- Newlines become CRLF before encoding, which is what a URL-encoded form
    -- field is specified to carry.
    local encoded_newline = encoding.urlencode("a\nb")
    H.contains(encoded_newline, "%0D%0A", "a newline becomes an encoded CRLF pair")

    -- Non-ASCII is encoded per UTF-8 byte, so a query survives the round trip
    -- to a forge that expects UTF-8.
    H.contains(encoding.urlencode("grüße"), "%C3%BC", "a multibyte character is encoded byte by byte")

    -- base64: the README API route's `content` field.
    H.eq(encoding.decode_base64(vim.base64.encode("# Title")), "# Title", "an encoded README decodes back")
    H.eq(encoding.decode_base64(""), "", "an empty payload decodes to an empty string")
    H.eq(
      encoding.decode_base64(vim.base64.encode("line one\nline two\n")),
      "line one\nline two\n",
      "newlines survive the round trip"
    )
    H.eq(encoding.decode_base64(vim.base64.encode("grüße")), "grüße", "and so does non-ASCII content")
  end

  ---------------------------------------------------------------------------
  -- text.cut_text_for_line
  ---------------------------------------------------------------------------
  do
    local text = require("reposcope.utils.text")

    H.eq(text.cut_text_for_line(0, 40, "short"), "short", "a line that fits is left alone")

    -- The budget is width - offset - 3, the three being the ellipsis itself,
    -- so the result never exceeds the window.
    local cut = text.cut_text_for_line(0, 10, "0123456789abcdef")
    H.eq(cut, "0123456...", "a long line is truncated with an ellipsis")
    H.eq(#cut, 10, "to exactly the available width")

    local indented = text.cut_text_for_line(4, 14, "0123456789abcdef")
    H.eq(#indented, 10, "an indent reduces the budget by its own size")

    -- The boundary: exactly at the budget is not truncated.
    H.eq(text.cut_text_for_line(0, 10, "0123456"), "0123456", "a line exactly at the budget is kept whole")
    H.eq(text.cut_text_for_line(0, 10, "01234567"), "0123456...", "one character more is truncated")
  end

  ---------------------------------------------------------------------------
  -- text.center_text
  ---------------------------------------------------------------------------
  do
    local text = require("reposcope.utils.text")

    local one = text.center_text("abc", 11)
    H.eq(#one, 1, "a short string stays on one line")
    H.eq(one[1], "    abc", "padded to centre it")

    H.eq(text.center_text("", 5)[1], "  ", "an empty string is centred as pure padding")
    -- 10 - 3 = 7 columns to share; the left side gets 3, so the text sits one
    -- column left of dead centre rather than one right.
    H.eq(text.center_text("abc", 10)[1], "   abc", "an odd remainder rounds the leading padding down")
    H.eq(
      text.center_text("exactly-ten", 11)[1],
      "exactly-ten",
      "a string exactly as wide as the window gets no padding"
    )
    H.eq(text.center_text("abc", 2)[1], "ab", "a width narrower than the text cuts rather than padding")

    -- A string wider than the window is split; the split must not cut a word
    -- in half when there is a space to break at.
    local wrapped = text.center_text("alpha beta gamma delta", 12)
    H.ok(#wrapped > 1, "a long string is split across lines")
    for _, line in ipairs(wrapped) do
      H.ok(#line <= 12, "no produced line exceeds the width")
    end
    local rejoined = table.concat(wrapped, " "):gsub("%s+", " "):gsub("^%s", "")
    H.contains(rejoined, "alpha", "the first word survives")
    H.contains(rejoined, "delta", "and so does the last")
    for _, word in ipairs({ "alpha", "beta", "gamma", "delta" }) do
      local found = false
      for _, line in ipairs(wrapped) do
        if line:find(word, 1, true) then found = true end
      end
      H.ok(found, "no word was broken across the split: " .. word)
    end

    -- A single word longer than the window has no space to break at, so it is
    -- cut at the width rather than overflowing it.
    local unbreakable = text.center_text("supercalifragilistic", 8)
    for _, line in ipairs(unbreakable) do
      H.ok(#line <= 8, "an unbreakable word is cut at the width, not allowed to overflow")
    end
    H.eq(table.concat(unbreakable):gsub("%s", ""), "supercalifragilistic", "and nothing is lost in the cut")

    local lines = text.center_text_lines({ "abc", "de" }, 9)
    H.eq(#lines, 2, "centring a list yields one line per input line")
    H.eq(lines[1], "   abc", "each centred on its own")
    H.eq(lines[2], "   de", "including the shorter one")

    -- A line in the list that has to wrap contributes several output lines.
    H.ok(
      #text.center_text_lines({ "alpha beta gamma delta", "x" }, 12) > 2,
      "a wrapping entry contributes several lines"
    )
  end

  ---------------------------------------------------------------------------
  -- text.gen_padded_lines
  ---------------------------------------------------------------------------
  do
    local text = require("reposcope.utils.text")

    local padded = text.gen_padded_lines(5, { "a", "b" })
    H.eq(#padded, 5, "the result is exactly as tall as asked for")
    H.eq(padded[2], "b", "the content comes first")
    H.eq(padded[3], "", "and the remainder is empty lines -- a window needs a line per row")

    local trimmed = text.gen_padded_lines(2, { "a", "b", "c", "d" })
    H.eq(#trimmed, 2, "too much content is trimmed, not overflowed")
    H.eq(trimmed[2], "b", "keeping the first lines")

    local from_string = text.gen_padded_lines(4, "one\ntwo\r\nthree")
    H.eq(from_string[1], "one", "a string is split on newlines")
    H.eq(from_string[2], "two", "CRLF included")
    H.eq(from_string[3], "three", "to the last line")
    H.eq(from_string[4], "", "and padded out")

    -- Neither shape must raise: this is called with whatever a provider sent.
    local bad = text.gen_padded_lines(3, 42)
    H.eq(#bad, 3, "an unusable content type still yields the right number of lines")
    H.eq(bad[1], "", "all of them empty")

    H.eq(#text.gen_padded_lines(0, { "a" }), 0, "a height of zero yields nothing")

    -- The input list must not be mutated: callers pass cached content.
    local source = { "a", "b" }
    text.gen_padded_lines(5, source)
    H.eq(#source, 2, "the caller's table is left as it was")
  end
end
