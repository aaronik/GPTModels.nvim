local util = require('gpt.util')
local uv = vim.loop
require('gpt.types')

local M = {}

-- Execute a command a la on the command line
---@param args ExecArgs
---@return Job
function M.exec(args)
  local stdin = vim.loop.new_pipe()
  local stdout = vim.loop.new_pipe()
  local stderr = vim.loop.new_pipe()

  local done = false

  local handle, pid = uv.spawn(args.cmd, {
    stdio = { stdin, stdout, stderr },
    args = args.args
  }, function(code, signal) -- on exit
    stdin:close()
    stdout:close()
    stderr:close()
    done = true
    if args.onexit then args.onexit(code, signal) end
  end)

  if args.onread then
    uv.read_start(stdout, function(_, data) args.onread(nil, data) end)
    uv.read_start(stderr, function(_, err) args.onread(err, nil) end)
  end

  return {
    handle = handle,
    pid = pid,
    done = function() return done end,
    die = function()
      if not handle then return end
      uv.process_kill(handle, 'sigterm')
      -- Give it a moment to terminate gracefully
      vim.defer_fn(function()
        if not handle:is_closing() then
          uv.shutdown(stdin, function()
            uv.close(handle)
          end)
        end
      end, 500)
    end,
  }
end

return M
