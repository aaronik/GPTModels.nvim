-- This file soas to get access to whether in visual mode or not
--
-- via https://www.petergundel.de/neovim/lua/hack/2023/12/17/get-neovim-mode-when-executing-a-command.html

local function models()
  -- For development only
  -- local util = require('gptmodels.util')
  -- return util.R('gptmodels')
  return require('gptmodels')
end

function InvokeGptModelsCode(opts)
  local gpt_opts = { visual_mode = opts.count ~= -1 }
  models().code(gpt_opts)
end

function InvokeGptModelsChat(opts)
  local gpt_opts = { visual_mode = opts.count ~= -1 }
  models().chat(gpt_opts)
end

vim.api.nvim_create_user_command(
  "GPTModelsCode",
  InvokeGptModelsCode,
  { nargs = "?", range = "%", addr = "lines" }
)

vim.api.nvim_create_user_command(
  "GPTModelsChat",
  InvokeGptModelsChat,
  { nargs = "?", range = "%", addr = "lines" }
)
