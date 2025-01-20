vim.notify = print

local lazypath = vim.fn.stdpath("data") .. "/lazy"

vim.notify = print
vim.opt.swapfile = false

vim.opt.rtp:append(".")
vim.opt.rtp:append(lazypath .. "/plenary.nvim")
vim.opt.rtp:append(lazypath .. "/nui.nvim")
vim.opt.rtp:append(lazypath .. "/telescope.nvim")

vim.cmd("runtime! plugin/GPTModels.nvim")
vim.cmd("runtime! plugin/plenary.vim")
vim.cmd("runtime! plugin/nui.nvim")
vim.cmd("runtime! plugin/telescope.nvim")
dofile("plugin/init.lua") -- get the :GPTModels commands present

