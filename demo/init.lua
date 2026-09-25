-- Editor for the recordings: `nvim --clean -u demo/init.lua`, run from the repo root
vim.opt.rtp:prepend('.')

vim.o.termguicolors = true
vim.o.number = true
vim.o.cursorline = true
vim.o.laststatus = 3
vim.o.showmode = false
vim.o.showcmd = false
vim.o.ruler = false
vim.o.shortmess = vim.o.shortmess .. 'IF'
vim.o.fillchars = 'eob: ,vert:│'
vim.o.swapfile = false
vim.cmd.colorscheme('default')

require('beside').setup({ width = 0.5 })
