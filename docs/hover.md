# hover.nvim integration

Rest the cursor on `owner/repo` anywhere — a plugin spec, a lockfile, a
dependency list, a note — and
[hover.nvim](https://github.com/StefanBartl/hover.nvim) previews that
repository's README.

```
{ "StefanBartl/hover.nvim", lazy = false }
        └──── hover here ────┘

┌ hover.nvim.md ────────────────────────┐
│ # hover.nvim                          │
│                                       │
│ Rest the cursor on something that     │
│ points at a file …                    │
└───────────────────────────────────────┘
```

Only for repositories reposcope has already fetched. Everything it needs is
local: the README cache survives restarts, so the answer costs a file read.

## How it works, and why it needs nothing on hover.nvim's side

hover.nvim takes a **source** ("what is under the cursor?") that returns a
target string. This one returns the *path of the cached README* rather than
the slug.

That indirection is the whole design. hover.nvim then sees a `.md` file,
classifies it as markdown, and runs its ordinary markdown preview — heading
rendering, scrolling, file-head logic, all of it already built. The
alternative was a `repository` target type with a preview to match, which
would have needed a change on hover.nvim's side and reimplemented what it
already does.

## The hazard, and the two things that contain it

**A slug is spelled exactly like prose.** `owner/repo` is two components, no
extension, no root — the same shape as `and/or`, `input/output`,
`read/write`. hover.nvim's bare-path rules deliberately refuse to treat those
as targets, and for good reason: a confident float over ordinary text is
worse than no float.

So the slug test is only half of it:

1. **The shape test.** Exactly two components, made of the characters GitHub,
   GitLab and Codeberg actually allow. `owner/repo/tree/main` is a path into a
   repository, not a slug; `just-a-word` is a word.
2. **The cache check.** It answers only for repositories reposcope has
   *actually cached*, never for arbitrary slug-shaped text. `and/or` is
   declined not because it looks wrong but because there is no such
   repository in the cache.

The second is what makes this safe, and it is the one no shape test could
replace. A dangling cache entry — the record is there, the file is gone —
is declined too, rather than handed over as a path that would preview
"no such file".

## Ordering

Registered sources are asked in registration order, before hover.nvim's own
bare-path source. So a slug that is *also* a real directory relative to the
buffer reads as the repository, which is the more specific reading of the
same text.

## Soft in both directions

- **Without hover.nvim**, `setup()` looks for `hover.registry`, does not find
  it, and returns. Nothing registered, nothing errors.
- **Without reposcope**, hover.nvim is unaffected — it never names this
  plugin.

## Turning it off

```lua
require("reposcope").setup({ hover = false })
```

## What it does not do

- **It does not fetch.** A repository reposcope has never shown has no cached
  README, and this will not go and get one — a float that made a network
  request because the cursor drifted over a slug would be exactly the
  disclosure hover.nvim's `links web fetch` is off by default to prevent.
- **It does not refresh.** The cached README is whatever was fetched last.
  `:Reposcope start` is what updates it.
