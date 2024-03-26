-- main module file
-- local module = require("undo-selection.module")

local config = {}

local M = {}

M.config = config

-- you can define your setup function here. Usually configurations can be merged, accepting outside params and
-- you can also put some validation here for those.
M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", M.config, args or {})
end

M.gpt = function()
  print('wo from gpt')
  -- local module = require('gpt.module')
  -- return module.gpt()
end

-- -- Assigning everything that module exposes to M
-- for k, v in pairs(module) do
--     M[k] = v
-- end

return M
