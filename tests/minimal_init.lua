vim.notify = print

local lazypath = vim.fn.stdpath("data") .. "/lazy"

vim.opt.rtp:append(".")
vim.opt.rtp:append(lazypath .. "/plenary.nvim")
vim.opt.rtp:append(lazypath .. "/nui.nvim")
vim.opt.rtp:append(lazypath .. "/telescope.nvim")

vim.opt.swapfile = false

vim.cmd("runtime! plugin/plenary.vim")

P = function(...)
  print(vim.inspect(...))
end
