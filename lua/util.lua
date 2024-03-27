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

return M
