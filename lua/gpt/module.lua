local M = {}

local util = require('util')

-- The main function
M.run = function()
  print(util.in_visual_mode())
  if not util.in_visual_mode() then
    return
  end
  util.log(util.pretty_print_table(util.get_visual_selection()))
end

return M
