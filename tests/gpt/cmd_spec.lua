---@diagnostic disable: undefined-global

local util = require("gpt.util")
local assert = require("luassert")
local stub = require('luassert.stub')
local cmd = require('gpt.cmd')

describe("cmd.exec", function()
  it("calls onread with data", function()
    local finished = false
    local dat = "initial"

    ---@type ExecArgs
    local exec_args = {
      cmd = "printf",
      args = { "woohoo" },
      onread = function(err, data)
        if err then error(err) end
        if data then dat = data end
      end,
      onexit = function()
        finished = true
      end
    }

    cmd.exec(exec_args)

    -- vim to wait up to 50ms until job's done
    vim.wait(50, function() return finished end)

    -- test cmd / args / onread happy path
    assert.same("woohoo", dat)

    -- test onexit is called
    assert.is_true(finished)
  end)

  it("calls onread with errors", function()
    local finished = false
    local e = "initial"

    ---@type ExecArgs
    local exec_args = {
      cmd = "ls",
      args = { "/thisdirdefinitelydoesntexistimsureofitforreal" },
      onread = function(err, data)
        if data then error(data) end
        if err then e = err end
      end,
      onexit = function(_, _)
        finished = true
      end
    }

    cmd.exec(exec_args)

    -- vim to wait up to _ ms until job's done
    vim.wait(50, function() return finished end)

    -- make sure the job exited w/o timing out
    assert.is_true(finished)

    -- That directory is definitely not found, which leads to a message to
    -- stderr with this in it
    assert(string.find(e, "No such file or directory") ~= nil)
  end)

  it("handles exit codes", function()
    local finished = false
    local cod = 0

    ---@type ExecArgs
    local exec_args = {
      cmd = "false",
      onexit = function(code, _)
        cod = code
        finished = true
      end
    }

    cmd.exec(exec_args)

    -- vim to wait up to 50ms until job's done
    vim.wait(50, function() return finished end)

    -- make sure the job exited w/o timing out
    assert.is_true(finished)

    -- `false` throws a 1
    assert.equal(1, cod)
  end)

  it("handles interrupts", function()
    local finished = false
    local sig = 0

    ---@type ExecArgs
    local exec_args = {
      cmd = "sleep",
      args = { "1" },
      onexit = function(_, signal)
        sig = signal
        finished = true
      end
    }

    local job = cmd.exec(exec_args)

    vim.wait(5)

    cmd.exec({ cmd = "kill", args = { "-9", tostring(job.pid) } })

    -- vim to wait up to 50ms until job's done
    vim.wait(50, function() return finished end)

    -- make sure the job exited w/o timing out
    assert.is_true(finished)

    assert.equal(sig, 9)
  end)

  it("die()s on command", function()
    local finished = false
    local sig = 0

    ---@type ExecArgs
    local exec_args = {
      cmd = "sleep",
      args = { "10" },
      onexit = function(_, signal)
        sig = signal
        finished = true
      end
    }

    local job = cmd.exec(exec_args)

    vim.wait(5)

    job.die()

    -- vim to wait up to _ ms until job's done
    vim.wait(500, function() return finished end)

    -- make sure the job exited w/o timing out
    assert.is_true(finished)

    -- 15 is sigterm, used in die()
    assert.equal(sig, 15)
  end)
end)
