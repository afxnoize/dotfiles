vim.keymap.set({ 'n', 'x', 'o' }, '<Leader>c', '<Plug>Commentary', { noremap = false, desc = 'Comment (operator)' })
vim.keymap.set('n', '<Leader>cc', '<Plug>CommentaryLine', { noremap = false, desc = 'Comment line' })
vim.keymap.set('n', '<Leader>cu', '<Plug>Commentary<Plug>Commentary', { noremap = false, desc = 'Uncomment' })
