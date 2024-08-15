local M = {}

---@param lines string[]
---@return Selection
M.build_selection = function(lines)
  ---@type Selection
  return {
    start_line = 0,
    end_line = 0,
    start_column = 0,
    end_column = 0,
    lines = lines
  }
end

return M
