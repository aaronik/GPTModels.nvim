-- This is meant to be a universally callable layer, which itself decides which llm to call
-- based on config or some state

require('gpt.types')
local Store = require('gpt.store')

local M = {}

--- Make request
---@param args MakeGenerateRequestArgs
---@return Job
M.generate = function(args)
  local provider = require('gpt.providers.' .. Store.llm_provider)
  args.llm.model = Store.llm_model
  return provider.generate(args)
end

--- Make request
---@param args MakeChatRequestArgs
---@return Job
M.chat = function(args)
  local provider = require('gpt.providers.' .. Store.llm_provider)
  args.llm.model = Store.llm_model
  return provider.chat(args)
end

return M

