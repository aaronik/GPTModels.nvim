-- lua/

local util = require('../util')

util.P(util)

local M = {}

-- you can define your setup function here. Usually configurations can be merged, accepting outside params and
-- you can also put some validation here for those.
local config = {}
M.config = config
M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", M.config, args or {})
end

-- The main function
M.run = function()
  print(util.in_visual_mode())
  if not util.in_visual_mode() then
    return
  end
  util.log(util.pretty_print_table(util.get_visual_selection()))
end

M.gpt = M.run

return M
