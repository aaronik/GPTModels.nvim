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

-- Log to the file debug.log in the root. File can be watched for easier debugging.
M.log = function(data)
  if type(data) == "table" then
    data = vim.inspect(data)
  end

  local log_file = io.open("./debug.log", "a")
  if not log_file then error("No log file found! It should be debug.log in the root.") end
  log_file:write(tostring(data) .. "\n")
  log_file:flush() -- Ensure the output is written immediately
  log_file:close()
end

M.dbg = function()
  require('debug').debug()
end

M.merge_tables = function(t1, t2)
  local new_table = {}
  for k, v in pairs(t1) do
    if type(k) == "number" then
      table.insert(new_table, v)
    else
      new_table[k] = v
    end
  end
  for k, v in pairs(t2) do
    if type(k) == "number" then
      table.insert(new_table, v)
    else
      new_table[k] = v
    end
  end
  return new_table
end

-- Just get some data about the current visual selection
M.get_visual_selection = function()
  local selection = {}
  selection.start_line = vim.fn.getpos("'<")[2]
  selection.end_line = vim.fn.getpos("'>")[2]
  selection.start_column = vim.fn.getpos("'<")[3]
  selection.end_column = vim.fn.getpos("'>")[3]

  local end_col = math.min(selection.end_column, 2147483646)
  local text = vim.api.nvim_buf_get_text(
    0, selection.start_line - 1, selection.start_column - 1, selection.end_line - 1, end_col, {}
  )

  selection.text = text

  return selection
end

return M
