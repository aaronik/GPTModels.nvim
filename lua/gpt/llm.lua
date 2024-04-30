-- This is meant to be a universally callable layer, which itself decides which llm to call
-- based on config or some state

require('gpt.types')
local ollama = require('gpt.adapters.ollama')

local M = {}

--- Make request
---@param args MakeChatRequestArgs
---@return Job
M.chat = function(args)
  -- This is where swapping out ollama for other supported llms will happen
  return ollama.chat(args)
end

--- Make request
---@param args MakeGenerateRequestArgs
---@return Job
M.generate = function(args)
  -- This is where swapping out ollama for other supported llms will happen
  return ollama.generate(args)
end

return M

