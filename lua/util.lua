-- Utility functions
local M = {}

M.P = function(v)
  print(vim.inspect(v))
  return v
end

M.RELOAD = function(...)
  return require("plenary.reload").reload_module(...)
end

M.R = function(name)
  M.RELOAD(name)
  return require(name)
end

function M.log(message)
  local log_file = io.open("./debug.log", "a")
  if not log_file then error("No log file found! It should be debug.log in the root.") end
  log_file:write(message .. "\n")
  log_file:flush() -- Ensure the output is written immediately
  log_file:close()
end

function M.dbg()
  require('debug').debug()
end

-- Note: requires command to be executed by user with <cmd> rather than :
function M.in_visual_mode()
  local mode = vim.api.nvim_get_mode().mode
  return mode == 'v' or mode == 'V' or mode == ''
end

-- Just get some data about the current visual selection
-- vim updates the getpos values _after exiting from visual mode_.
-- That means using <cmd> to invoke will result in stale info.
-- But without <cmd>, using :, we can't tell if we were in visual mode.
-- What a world.
function M.get_visual_selection()
  local selection = {}
  selection.start_line = vim.fn.getpos("'<")[2]
  selection.end_line = vim.fn.getpos("'>")[2]
  selection.start_column = vim.fn.getpos("'<")[3]
  selection.end_column = vim.fn.getpos("'>")[3]
  return selection
end

-- function M.get_visual_selection()
--   -- Save current cursor position
--   local save_pos = vim.api.nvim_win_get_cursor(0)
--   -- Move to start of visual selection
--   vim.cmd('normal! gv"<Esc>"')
--   local start_line, start_col = unpack(vim.api.nvim_win_get_cursor(0))
--   -- Move to end of visual selection
--   vim.cmd('normal! gvo"<Esc>"')
--   local end_line, end_col = unpack(vim.api.nvim_win_get_cursor(0))
--   -- Restore cursor position
--   vim.api.nvim_win_set_cursor(0, save_pos)
--   -- Adjust for Vim's 1-based indexing
--   start_col = start_col + 1
--   end_col = end_col + 1
--   return {
--     start_line = start_line,
--     start_column = start_col,
--     end_line = end_line,
--     end_column = end_col,
--   }
-- end

return M
