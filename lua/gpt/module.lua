local M = {}

local util = require('util')

-- The main function
M.gpt = function()
  print(M.in_visual_mode())
  util.log(util.pretty_print_table(M.get_visual_selection()))
end

-- Just get some data about the current visual selection
M.get_visual_selection = function()
  local selection = {}
  selection.start_line = vim.fn.getpos("'<")[2]
  selection.end_line = vim.fn.getpos("'>")[2]
  selection.start_column = vim.fn.getpos("'<")[3]
  selection.end_column = vim.fn.getpos("'>")[3]
  return selection
end

-- Note: requires command to be executed by user with <cmd> rather than :
M.in_visual_mode = function()
  local mode = vim.api.nvim_get_mode().mode
  return mode == 'v' or mode == 'V' or mode == ''
end

return M
