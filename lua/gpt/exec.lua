local util = require('gpt.util')
local job = require('plenary.job')
local uv = vim.loop
require('gpt.types')

local M = {}

-- Execute a command a la on the command line
---@param cmd string
---@param args string[]?
---@return uv_process_t | nil, string | integer
function M.exec(cmd, args)
  local stdin = vim.loop.new_pipe()
  local stdout = vim.loop.new_pipe()
  local stderr = vim.loop.new_pipe()

  local handle, pid = uv.spawn(cmd, {
    stdio = { stdin, stdout, stderr },
    args = args
  }, function(code, signal) -- on exit
    print("exit code", code)
    print("exit signal", signal)
  end)

  -- vim.loop.shutdown(stdin, function()
  --   vim.loop.close(handle, function()
  --   end)
  -- end)

  return handle, pid
end

-- Kill a process
---@param pid string | integer -- process id obvs
function M.kill(pid)
  M.exec("kill -2 " .. pid)
end

return M.exec
