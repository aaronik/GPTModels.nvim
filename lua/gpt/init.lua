local util = require('gpt.util')
local code_window = require("gpt.windows.code")
local chat_window = require("gpt.windows.chat")

local M = {}

-- you can define your setup function here. Usually configurations can be merged, accepting outside params and
-- you can also put some validation here for those.
local config = {}
M.config = config
M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", M.config, args or {})
end

---@param opts { visual_mode: boolean }
---@see file plugin/init.lua
M.code = function(opts)
  if opts.visual_mode then
    local selected_text = util.get_visual_selection().text
    code_window.build_and_mount(selected_text)
  else
    code_window.build_and_mount()
  end
end

---@param opts { visual_mode: boolean }
---@see file plugin/init.lua
M.chat = function (opts)
  if opts.visual_mode then
    local selected_text = util.get_visual_selection().text
    chat_window.build_and_mount(selected_text)
  else
    chat_window.build_and_mount()
  end

end

return M
