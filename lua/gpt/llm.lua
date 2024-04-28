-- This is meant to be a universally callable layer, which itself decides which llm to call
-- based on config or some state

local ollama = require('gpt.adapters.ollama')

local M = {}

---@class Args
---@field prompt string
---@field model string | nil
---@field stream boolean
---@field on_response fun(response: string)
---@field on_end function | nil
---@field on_error fun(message: string) | nil

--- Make request
---@param args Args
---@return nil
M.make_request = function(args)
  local prompt = args.prompt
  local model = args.model or "llama3"
  local on_response = args.on_response
  local on_end = args.on_end or function() end
  local on_error = args.on_error or function() end
  local stream = args.stream or true

  -- TODO swap out ollama for other supported llms
  ollama.make_request(prompt, model, on_response, on_end, on_error, stream)
end

return M
