-- TESTS/core_utils_spec.lua — reposcope.utils.core: the small pure helpers the
-- rest of the plugin is built on. Nothing here touches the network or the UI.

return function(H)
  local core = require("reposcope.utils.core")

  -- tbl_find ------------------------------------------------------------------
  H.eq(core.tbl_find({ "a", "b", "c" }, "b"), 2, "returns the index")
  H.eq(core.tbl_find({ "a" }, "z"), nil, "and nil when absent")
  H.eq(core.tbl_find({}, "a"), nil, "an empty list finds nothing")

  -- tbl_islist ----------------------------------------------------------------
  H.ok(core.tbl_islist({ 1, 2, 3 }), "1..n is a list")
  H.ok(core.tbl_islist({}), "so is the empty table")
  H.falsy(core.tbl_islist({ [1] = "a", [3] = "c" }), "a gap is not")
  H.falsy(core.tbl_islist({ a = 1 }), "nor are string keys")
  H.falsy(core.tbl_islist("nope"), "nor a non-table")

  -- flatten_table -------------------------------------------------------------
  local flat = core.flatten_table({ "a", { "b", { "c" } }, "d" })
  H.eq(#flat, 4, "nesting is flattened to one level")
  H.ok(vim.tbl_contains(flat, "c"), "including the deepest value")
  H.eq(core.flatten_table("scalar")[1], "scalar", "a scalar becomes a one-element list")

  -- dedupe_list ---------------------------------------------------------------
  local deduped = core.dedupe_list({ "a", "b", "a", "c", "b" })
  H.eq(#deduped, 3, "duplicates are removed")
  H.eq(deduped[1], "a", "and the first occurrence keeps its position")
  H.eq(deduped[2], "b", "order is preserved")
  H.eq(#core.dedupe_list("not a table"), 0, "a non-table yields an empty list")

  -- put_to_front_if_present ---------------------------------------------------
  -- This is what makes the last-used request tool or provider come up first
  -- without dropping the others.
  local fronted = core.put_to_front_if_present({ "curl", "gh", "wget" }, "wget")
  H.eq(fronted[1], "wget", "the named value moves to the front")
  H.eq(#fronted, 3, "and nothing is lost")
  H.eq(fronted[2], "curl", "the rest keep their relative order")

  local absent = core.put_to_front_if_present({ "curl", "gh" }, "wget")
  H.eq(#absent, 2, "a value that is not there changes nothing")
  H.eq(absent[1], "curl", "and the list is returned as it was")

  H.eq(#core.put_to_front_if_present("nope", "x"), 0, "a non-list yields an empty list")

  -- ensure_string -------------------------------------------------------------
  -- Values arriving from decoded JSON can be `vim.NIL`, which is a userdata and
  -- would render as "userdata: 0x..." if it ever reached a buffer.
  H.eq(core.ensure_string("text"), "text", "a string passes through")
  H.eq(core.ensure_string(nil), "", "nil becomes empty")
  H.eq(core.ensure_string(vim.NIL), "", "and so does vim.NIL, which JSON decoding produces")
  H.eq(core.ensure_string(42), "42", "other values are stringified")

  -- generate_uuid -------------------------------------------------------------
  local a, b = core.generate_uuid(), core.generate_uuid()
  H.ok(type(a) == "string" and #a > 0, "a uuid is a non-empty string")
  H.ok(a ~= b, "two calls do not collide")
end
