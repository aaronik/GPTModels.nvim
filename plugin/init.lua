-- This file soas to get access to whether in visual mode or not
--
-- via https://www.petergundel.de/neovim/lua/hack/2023/12/17/get-neovim-mode-when-executing-a-command.html

local util = require('gpt.util')

function InvokeGpt(opts, preview_ns, preview_buffer)
  local gpt_opts = {
    visual_mode = opts.count ~= -1
  }

  -- Load the code on the first time it's run, rather than on startup.
  -- This behavior will likely have to be reconsidered
  -- TODO regular require
  util.R('gpt').run(gpt_opts);
end

vim.api.nvim_create_user_command(
  "GPT",
  InvokeGpt,
  { nargs = "?", range = "%", addr = "lines" }
)
