---@diagnostic disable: undefined-global

local job = require('plenary.job')
local util = require("gpt.util")
local assert = require("luassert")
local stub = require('luassert.stub')
local exec = require('gpt.exec')

describe("exec", function()
  it("runs a command", function()
    local handle, pid = exec("ls")
  end)
end)
