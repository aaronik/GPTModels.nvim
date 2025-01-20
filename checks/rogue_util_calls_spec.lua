-- This spec ensures there's nowhere in the code that calls undesirable
-- util functions like R and log. This isn't perfect, as it tries to exercise
-- each command, but doesn't seek edge cases.

local assert = require 'luassert'
local stub = require 'luassert.stub'
local util = require 'gptmodels.util'

local commands = {
  "GPTModelsChat",
  "GPTModelsCode",
}

describe("Extent util calls:", function()
  local orig_R = util.R
  local orig_log = util.log
  local util_R_stub = stub(util, "R")
  local util_log_stub = stub(util, "log")
  util_R_stub.callback = orig_R
  util_log_stub.callback = orig_log

  for _, command in ipairs(commands) do
    it(command .. " encounters no " .. "util.R calls", function()
      vim.cmd(command)
      assert.stub(util_R_stub).was.called(0)
    end)

    it(command .. " encounters no " .. "util.log calls", function()
      vim.cmd(command)
      assert.stub(util_log_stub).was.called(0)
    end)
  end
end)
