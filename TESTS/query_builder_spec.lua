-- TESTS/query_builder_spec.lua — the provider query builders: turning the
-- prompt's structured input into each forge's own search syntax.
--
-- The three providers differ, and that difference is the point: the same
-- prompt has to become `user:x` on GitHub and whatever GitLab and Codeberg
-- expect. Each is asserted against its own module rather than a shared shape.

return function(H)
  local github = require("reposcope.providers.github.query_builder")

  -- Filter keys ---------------------------------------------------------------
  H.eq(github.build({ owner = "neovim" }), "owner:neovim", "a filter key becomes a qualifier")
  H.eq(github.build({ language = "lua" }), "language:lua", "each mapped key is recognised")

  -- Loose keywords ------------------------------------------------------------
  H.eq(github.build({ keywords = "telescope" }), "telescope", "unmapped text is a bare keyword")

  -- `prefix` is the prompt's own marker, not part of the search ----------------
  H.eq(github.build({ prefix = "gh", keywords = "fzf" }), "fzf", "the prompt prefix is dropped")

  -- Empty and invalid input ---------------------------------------------------
  H.eq(github.build({}), "", "an empty table builds an empty query")
  H.eq(github.build({ owner = "" }), "", "an empty value contributes nothing")
  H.eq(github.build(nil), "", "and a non-table is not a crash")
  H.eq(github.build("string"), "", "whatever the caller passes")

  -- Composition ---------------------------------------------------------------
  -- Field order comes from `pairs`, so assert on membership rather than on the
  -- exact string: what matters is that both parts are in there, once.
  local composed = github.build({ owner = "neovim", language = "lua" })
  H.contains(composed, "owner:neovim", "both qualifiers appear")
  H.contains(composed, "language:lua", "the second one too")
  H.eq(select(2, composed:gsub(" ", " ")), 1, "joined by exactly one space")

  -- The other providers -------------------------------------------------------
  for _, name in ipairs({ "gitlab", "codeberg" }) do
    local ok, mod = pcall(require, "reposcope.providers." .. name .. ".query_builder")
    if ok then
      H.eq(mod.build(nil), "", name .. ": a non-table builds an empty query")
      H.eq(mod.build({}), "", name .. ": an empty table too")
      H.ok(type(mod.build({ keywords = "x" })) == "string", name .. ": always returns a string")
    end
  end
end
