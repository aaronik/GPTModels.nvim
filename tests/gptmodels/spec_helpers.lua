local stub = require('luassert.stub')

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
M.stub_schedule_wrap = function ()
  stub(vim, "schedule_wrap").invokes(function(cb)
    return function(...)
      cb(...)
    end
  end)
end

return M
