-- This file soas to get access to whether in visual mode or not
--
-- via https://www.petergundel.de/neovim/lua/hack/2023/12/17/get-neovim-mode-when-executing-a-command.html

local util = require('gpt.util')

function InvokeGptCode(opts, preview_ns, preview_buffer)
  local gpt_opts = {
    visual_mode = opts.count ~= -1
  }

  -- TODO use regular require
  util.R('gpt').code(gpt_opts);
  -- require('gpt').code(gpt_opts)
end

function InvokeGptChat(opts, preview_ns, preview_buffer)
  local gpt_opts = {
    visual_mode = opts.count ~= -1
  }

  -- TODO use regular require
  util.R('gpt').chat(gpt_opts);
  -- require('gpt').chat(gpt_opts)
end

vim.api.nvim_create_user_command(
  "GPTCode",
  InvokeGptCode,
  { nargs = "?", range = "%", addr = "lines" }
)

vim.api.nvim_create_user_command(
  "GPTChat",
  InvokeGptChat,
  { nargs = "?", range = "%", addr = "lines" }
)
