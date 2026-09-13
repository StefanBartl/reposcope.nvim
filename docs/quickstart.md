# Quickstart

https://github.com/user-attachments/assets/85dece1d-d755-4de9-9cd1-84a751901fc2

Open the picker:

```vim
:Reposcope start
```

Type into a prompt field, `<CR>` to search, `<Up>`/`<Down>` through the results
— the README of the selected repository renders in the preview as you move —
and `<C-c>` to clone the one you want. `<Tab>` cycles prompt fields, `<C-f>`
favorites a repository, `?` lists every key, `<Esc>` closes.

Then, later, for the clones you already have:

```vim
:Reposcope status
```

An interactive overview of every repository in your clone directory — branch,
ahead/behind, dirty state, last-commit age. Mark a set with `m` and `p`, `P` or
`f` to push, pull or fetch all of them; `gu` updates the whole folder.

Verify your setup any time with:

```vim
:checkhealth reposcope
```

See [what-you-get.md](what-you-get.md) for the rest of the surface at a
glance, or [commands.md](commands.md) for the full reference.
