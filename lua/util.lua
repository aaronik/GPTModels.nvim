-- Utility functions
local M = {}

function M.log(message)
  local log_file = io.open("./debug.log", "a")
  if not log_file then error("No log file found!") end
  log_file:write(message .. "\n")
  log_file:flush() -- Ensure the output is written immediately
  log_file:close()
end

function M.pretty_print_table(tbl, indent)
  local result = ""
  if not indent then indent = 0 end
  for k, v in pairs(tbl) do
    if type(v) == "table" and indent <= 0 then
      result = result .. "\n" .. string.rep(" ", indent) .. tostring(k) .. ": " .. M.pretty_print_table(v, indent + 2)
    else
      result = result .. "\n" .. string.rep(" ", indent) .. tostring(k) .. ": " .. tostring(v)
    end
  end
  return result
end

function M.dbg()
  require('debug').debug()
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

-- Note: requires command to be executed by user with <cmd> rather than :
function M.in_visual_mode()
  local mode = vim.api.nvim_get_mode().mode
  return mode == 'v' or mode == 'V' or mode == ''
end

return M
