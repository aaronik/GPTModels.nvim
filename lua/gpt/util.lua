-- Utility functions
local M = {}

-- remove program code from lua cache, reload
M.RELOAD = function(...)
  return require("plenary.reload").reload_module(...)
end

-- modified 'require'; use to flush entire program from top level for plugin development.
M.R = function(name)
  M.RELOAD(name)
  return require(name)
end

-- print tables contents
M.P = function(v)
  print(vim.inspect(v))
  return v
end

---Log to the file debug.log in the root. File can be watched for easier debugging.
---@param ... (table | string)[]
M.log = function(...)
  -- local args = {...}

  local loggables = vim.inspect(...)

  local log_file = io.open("./debug.log", "a")
  if not log_file then error("No log file found! It should be debug.log in the root.") end
  log_file:write(tostring(loggables) .. "\n")
  log_file:flush() -- Ensure the output is written immediately
  log_file:close()
end

---Found out in python you can do dict1 | dict2 to produce a merged dict. Wish lua had that.
---* shallow merge
---* doesn't write to t1 or t2
---* returns new table t3 with all keys from t1 and t2
---* keys from t2 will overwrite t1
---@param t1 table
---@param t2 table
---@return table
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

---Get useful data about the current visual selection
---@return {start_line: number, end_line: number, start_column: number, end_column: number, text: string[]}
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
