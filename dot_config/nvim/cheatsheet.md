# CheatSheet

- In INSERT mode
  - `Ctrl-W`: delete word (back cursor)
- In CommandLine mode
  - `Ctrl-R` + `register`: paste register
- `m<Space>`: **FuzzyMotion** (`m` is `[motion]` prefix)
- `]F`: format using LSP (`vim.lsp.buf.format`)

## memo

- `zo`, `zO`: opening the fold
- `,tt`: terminal toggle (floaterm)
- `,r`: source myvimrc
- `,?`: open this cheatsheet

## plugins

- `<C-a>`,`<C-x>`強化: `monaqa/dial.nvim`
- overviewer `stevearc/aerial.nvim` `:AerialOpen`
- `thinca/vim-partedit` `:<range>Partedit`
- `trouble.nvim` `:Trouble`

## cmp

- `<C-l>`: complete
- `<C-e>`: close

## operators

- `R[obj]`: replace [obj] to register
- `sa/sd/sr[obj]`: surround

## telescope

- `,fF`: **telescope** builtin
- `sf`: file browser

## markdown preview (md-render.nvim)

- `,pp`: preview (toggle)
- `,pt`: preview in tab (toggle)
- `,pd`: render demo

## quickfix

- `:lua vim.diagnostic.setqflist()`

## TODO
- [ ] 
