---@diagnostic disable: undefined-global

local util = require("gptmodels.util")
local assert = require("luassert")
local stub = require('luassert.stub')
local cmd = require('gptmodels.cmd')

describe("cmd.exec", function()
  it("calls onread with data", function()
    local dat = "initial"

    ---@type ExecArgs
    local exec_args = {
      sync = false,
      cmd = "printf",
      args = { "woohoo" },
      onread = function(err, data)
        if err then error(err) end
        if data then dat = data end
      end,
    }

    local job = cmd.exec(exec_args)

    -- vim to wait up to 50ms until job's done
    vim.wait(50, function() return job.done() end)

    -- test cmd / args / onread happy path
    assert.same("woohoo", dat)

    -- ensure job.done() works
    assert.is_true(job.done())
  end)

  it("calls onread with errors", function()
    local e = "initial"

    ---@type ExecArgs
    local exec_args = {
      sync = false,
      cmd = "ls",
      args = { "/thisdirdefinitelydoesntexistimsureofitforreal" },
      onread = function(err, data)
        if data then error(data) end
        if err then e = err end
      end,
    }

    local job = cmd.exec(exec_args)

    -- vim to wait up to _ ms until job's done
    vim.wait(100, function() return job.done() end)

    -- make sure the job exited w/o timing out
    assert.is_true(job.done())

    -- That directory is definitely not found, which leads to a message to
    -- stderr with this in it
    assert(string.find(e, "No such file or directory") ~= nil)
  end)

  it("handles exit codes", function()
    local cod = 0

    ---@type ExecArgs
    local exec_args = {
      sync = false,
      cmd = "false",
      onexit = function(code, _)
        cod = code
      end
    }

    local job = cmd.exec(exec_args)

    -- vim to wait up to 50ms until job's done
    vim.wait(50, function() return job.done() end)

    -- make sure the job exited w/o timing out
    assert.is_true(job.done())

    -- `false` throws a 1
    assert.equal(1, cod)
  end)

  it("handles interrupts", function()
    local sig = 0

    ---@type ExecArgs
    local exec_args = {
      sync = false,
      cmd = "sleep",
      args = { "1" },
      onexit = function(_, signal)
        sig = signal
      end
    }

    local job = cmd.exec(exec_args)

    vim.wait(5)

    cmd.exec({ cmd = "kill", args = { "-9", tostring(job.pid) } })

    -- vim to wait up to 50ms until job's done
    vim.wait(50, function() return job.done() end)

    -- make sure the job exited w/o timing out
    assert.is_true(job.done())

    assert.equal(9, sig)
  end)

  it("die()s on command", function()
    local sig = 0

    ---@type ExecArgs
    local exec_args = {
      sync = false,
      cmd = "sleep",
      args = { "10" },
      onexit = function(_, signal)
        sig = signal
      end
    }

    local job = cmd.exec(exec_args)

    vim.wait(5)

    job.die()

    -- vim to wait up to _ ms until job's done
    vim.wait(500, function() return job.done() end)

    -- make sure the job exited w/o timing out
    assert.is_true(job.done())

    -- 15 is sigterm, used in die()
    assert.equal(15, sig)
  end)

  it("can exec synchronously", function()
    local sig = signal

    ---@type ExecArgs
    local exec_args = {
      sync = true,
      cmd = "sleep",
      args = { "0.05" },
      onexit = function(_, signal)
        sig = signal
      end
    }

    local job = cmd.exec(exec_args)

    -- The job should run synchronously, so by the time we get here, it should already
    -- have finished, and sig should already be OK
    job.die()

    assert.equal(0, sig)
  end)
end)
