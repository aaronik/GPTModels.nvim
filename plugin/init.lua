-- This file soas to get access to whether in visual mode or not
--
-- via https://www.petergundel.de/neovim/lua/hack/2023/12/17/get-neovim-mode-when-executing-a-command.html

local util = require('gpt.util')

function InvokeGptModelsCode(opts, preview_ns, preview_buffer)
  local gpt_opts = {
    visual_mode = opts.count ~= -1
  }

  -- For development only
  -- util.R('gpt').code(gpt_opts);
  require('gpt').code(gpt_opts)
end

function InvokeGptModelsChat(opts, preview_ns, preview_buffer)
  local gpt_opts = {
    visual_mode = opts.count ~= -1
  }

  -- For development only
  -- util.R('gpt').chat(gpt_opts);
  require('gpt').chat(gpt_opts)
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
