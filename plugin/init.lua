-- This file soas to get access to whether in visual mode or not
--
-- via https://www.petergundel.de/neovim/lua/hack/2023/12/17/get-neovim-mode-when-executing-a-command.html

local util = require('gptmodels.util')

function InvokeGptModelsCode(opts, preview_ns, preview_buffer)
  local gpt_opts = {
    visual_mode = opts.count ~= -1
  }

  -- For development only
  util.R('gptmodels').code(gpt_opts);
  -- require('gptmodels').code(gpt_opts)
end

function InvokeGptModelsChat(opts, preview_ns, preview_buffer)
  local gpt_opts = {
    visual_mode = opts.count ~= -1
  }

  -- For development only
  util.R('gptmodels').chat(gpt_opts);
  -- require('gptmodels').chat(gpt_opts)
end

function InvokeGptModelsProject(opts, preview_ns, preview_buffer)
  local gpt_opts = {
    visual_mode = opts.count ~= -1
  }

  -- For development only
  util.R('gptmodels').project(gpt_opts);
  -- require('gptmodels').project(gpt_opts)
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

vim.api.nvim_create_user_command(
  "GPTModelsProject",
  InvokeGptModelsProject,
  { nargs = "?", range = "%", addr = "lines" }
)
