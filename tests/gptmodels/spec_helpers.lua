local stub = require('luassert.stub')
local cmd = require('gptmodels.cmd')
local Store = require('gptmodels.store')
local assert = require("luassert")

local M = {}

---@param lines string[]
---@return Selection
M.build_selection = function(lines)
  ---@type Selection
  return {
    start_line = 0,
    end_line = 0,
    start_column = 0,
    end_column = 0,
    lines = lines
  }
end

-- Feed keys to neovim; keys are pressed no matter what vim mode or state
---@param keys string
---@return nil
M.feed_keys = function(keys)
  local termcodes = vim.api.nvim_replace_termcodes(keys, true, true, true)
  vim.api.nvim_feedkeys(termcodes, 'mtx', false)
end

-- For async functions that use vim.schedule_wrap, which writing to buffers requires
M.stub_schedule_wrap = function()
  stub(vim, "schedule_wrap").invokes(function(cb)
    return function(...)
      cb(...)
    end
  end)
end

-- Triggers before/after(each) calls to get a clean state for each spec. Put in describe() block.
M.reset_state = function()
  local snapshot

  before_each(function()
    -- Set current window dims, otherwise it defaults to 0 and nui.layout complains about not having a pos integer height
    vim.api.nvim_win_set_height(0, 100)
    vim.api.nvim_win_set_width(0, 100)

    -- clear cmd history, lest it get remembered and bleed across tests
    vim.fn.histdel('cmd')

    -- stubbing cmd.exec prevents the llm call from happening
    stub(cmd, "exec")

    Store:clear()
    snapshot = assert:snapshot()
  end)

  after_each(function()
    snapshot:revert()
  end)
end

M.seed_store = function ()
  before_each(function()
    Store:set_models("ollama", { "ollama1", "ollama2" })
    Store:set_models("openai", { "openai1", "openai2" })
    Store:correct_potentially_missing_current_model()
  end)
end

return M
