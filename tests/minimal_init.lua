local lazypath = vim.fn.stdpath("data") .. "/lazy"
vim.notify = print
vim.opt.rtp:append(".")
vim.opt.rtp:append(lazypath .. "/plenary.nvim")
vim.opt.rtp:append(lazypath .. "/nui.nvim")
vim.opt.rtp:append(lazypath .. "/telescope.nvim")
-- vim.opt.rtp:append(lazypath .. "/nvim-nio")

-- -- Get all our normal plugins into the test env
-- local suite = os.getenv("SUITE")
-- vim.opt.rtp:append(suite .. "nvim")

vim.opt.swapfile = false

vim.cmd("runtime! plugin/plenary.vim")

P = function(...)
  print(vim.inspect(...))
end
