-- This file soas to get access to whether in visual mode or not
--
-- via https://www.petergundel.de/neovim/lua/hack/2023/12/17/get-neovim-mode-when-executing-a-command.html

local function models()
  if os.getenv("GPTMODELS_NVIM_ENV") == "development" then
    -- For development. Makes the plugin auto-reload so you
    -- don't need to restart nvim to get the changes live.
    -- F*** it, we're doing it live! kinda thing.
    local util = require('gptmodels.util')
    return util.R('gptmodels')
  else
    return require('gptmodels')
  end

end

local function code_with_vis_ops(opts)
  local gpt_opts = { visual_mode = opts.count ~= -1 }
  models().code(gpt_opts)
end

local function chat_with_vis_ops(opts)
  local gpt_opts = { visual_mode = opts.count ~= -1 }
  models().chat(gpt_opts)
end

vim.api.nvim_create_user_command(
  "GPTModelsCode",
  code_with_vis_ops,
  { nargs = "?", range = "%", addr = "lines" }
)

vim.api.nvim_create_user_command(
  "GPTModelsChat",
  chat_with_vis_ops,
  { nargs = "?", range = "%", addr = "lines" }
)
