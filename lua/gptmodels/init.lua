local util = require('gptmodels.util')
local code_window = require("gptmodels.windows.code")
local chat_window = require("gptmodels.windows.chat")
local project_window = require("gptmodels.windows.project")

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
    local selection = util.get_visual_selection()
    code_window.build_and_mount(selection)
  else
    code_window.build_and_mount()
  end
end

---@param opts { visual_mode: boolean }
---@see file plugin/init.lua
M.chat = function (opts)
  if opts.visual_mode then
    local selection = util.get_visual_selection()
    chat_window.build_and_mount(selection)
  else
    chat_window.build_and_mount()
  end
end

---@param opts { visual_mode: boolean }
---@see file plugin/init.lua
M.project = function (opts)
  if opts.visual_mode then
    local selection = util.get_visual_selection()
    project_window.build_and_mount(selection)
  else
    project_window.build_and_mount()
  end
end

return M
