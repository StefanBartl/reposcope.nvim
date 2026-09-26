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

Then, later, for the clones you already have — a git-status dashboard
across the whole folder, push/pull/fetch per row or per marked set — see
[gitsuite.nvim](https://github.com/StefanBartl/gitsuite.nvim)'s `:Git
dashboard`.

Verify your setup any time with:

```vim
:checkhealth reposcope
```

See [what-you-get.md](what-you-get.md) for the rest of the surface at a
glance, or [commands.md](commands.md) for the full reference.
