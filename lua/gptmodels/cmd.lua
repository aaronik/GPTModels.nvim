local util = require('gptmodels.util')
local uv = vim.uv
require('gptmodels.types')

local M = {}

-- Execute a command a la on the command line
---@param args ExecArgs
---@return Job
function M.exec(args)
  local stdin = uv.new_pipe()
  local stdout = uv.new_pipe()
  local stderr = uv.new_pipe()

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
    uv.read_start(stdout, function(err, data) args.onread(err, data) end)
    uv.read_start(stderr, function(_, err) args.onread(err, nil) end)
  end

  if args.sync then
    -- arbitrarily chosen, don't love that it's built in here
    vim.wait(2 * 60 * 1000, function() return done end)
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
