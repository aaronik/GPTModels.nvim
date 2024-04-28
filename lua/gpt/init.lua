local util = require('gpt.util')
local edit_window = require("gpt.windows.edit")
local chat_window = require("gpt.windows.chat")

local M = {}

-- you can define your setup function here. Usually configurations can be merged, accepting outside params and
-- you can also put some validation here for those.
local config = {}
M.config = config
M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", M.config, args or {})
end

-- The main function
---@param opts { visual_mode: boolean }
M.run = function(opts)
  if opts.visual_mode then
    local selected_text = util.get_visual_selection().text
    edit_window.build_and_mount(selected_text)
  else
    chat_window.build_and_mount()
  end
end

M.gpt = M.run

return M
