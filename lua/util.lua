-- Utility functions
local M = {}

-- function that prints a table
function M.print_table(t, indent)
  package.loaded['util'] = nil
  indent = indent or 0
  for k, v in pairs(t) do
    if type(v) == "table" then
      print(string.rep(" ", indent) .. k .. ": ")
      M.print_table(v, indent + 2)
    else
      print(string.rep(" ", indent) .. k .. ": " .. tostring(v))
    end
  end
end

return M
