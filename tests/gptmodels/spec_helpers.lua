local stub = require('luassert.stub')
local cmd = require('gptmodels.cmd')
local Store = require('gptmodels.store')
local assert = require("luassert")

local M = {}

-- Since GPTModels can be called from visual mode and receive a selection
---@param lines string[]
---@return Selection
M.generate_selection = function(lines)
  ---@type Selection
  return {
    start_line = 0,
    end_line = 0,
    start_column = 0,
    end_column = 0,
    lines = lines
  }
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
M.hook_reset_state = function()
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

M.hook_seed_store = function()
  before_each(function()
    Store:set_models("ollama", { "ollama1", "ollama2" })
    Store:set_models("openai", { "openai1", "openai2" })
    Store:correct_potentially_missing_current_model()
  end)
end

-- Feed keys to neovim; keys are pressed no matter what vim mode or state
---@param keys string
---@return nil
M.feed_keys = function(keys)
  local termcodes = vim.api.nvim_replace_termcodes(keys, true, true, true)
  return vim.api.nvim_feedkeys(termcodes, 'mtx', false)
end

---@param popup NuiPopup
---@param lines string[]
M.set_popup_lines = function(popup, lines)
  return vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, true, lines)
end

---@param popup NuiPopup
M.get_popup_lines = function(popup)
  -- local input_lines = vim.api.nvim_buf_get_lines(chat.input.bufnr, 0, -1, true)
  return vim.api.nvim_buf_get_lines(popup.bufnr, 0, -1, true)
end

-- Simulate a job, og for llm stub return values
M.fake_job = function()
  local die_called = false
  return {
      die = function()
        die_called = true
      end,
      done = function()
        return die_called
      end
    }
end

-- Get the given stub's first call's arguments
---@param stoob any -- TODO Wait do we not have typing for stubs!?
M.stub_args = function(stoob)
  return stoob.calls[1].refs[1]
end

return M
