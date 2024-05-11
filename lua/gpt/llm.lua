-- This is meant to be a universally callable layer, which itself decides which llm to call
-- based on config or some state

require('gpt.types')
local adapter = require('gpt.adapters.openai')

local M = {}

--- Make request
---@param args MakeGenerateRequestArgs
---@return Job
M.generate = function(args)
  -- This is where swapping out ollama for other supported llms will happen
  return adapter.generate(args)
end

--- Make request
---@param args MakeChatRequestArgs
---@return Job
M.chat = function(args)
  -- This is where swapping out ollama for other supported llms will happen
  return adapter.chat(args)
end

return M

