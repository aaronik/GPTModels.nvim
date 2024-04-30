-- This is meant to be a universally callable layer, which itself decides which llm to call
-- based on config or some state

require('gpt.types')
local ollama = require('gpt.adapters.ollama')

local M = {}

--- Make request
---@param args MakeRequestArgs
---@return nil
M.make_request = function(args)
  -- This is where swapping out ollama for other supported llms will happen
  ollama.make_request(args)
end

return M

