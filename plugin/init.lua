-- This file soas to get access to whether in visual mode or not
--
-- via https://www.petergundel.de/neovim/lua/hack/2023/12/17/get-neovim-mode-when-executing-a-command.html

local function models()
  -- For development only
  -- local util = require('gptmodels.util')
  -- return util.R('gptmodels')
  return require('gptmodels')
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
