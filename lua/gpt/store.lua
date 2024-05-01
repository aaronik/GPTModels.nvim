local Store = {}

-- TODO This becomes a file store
---@type LlmMessage[]
Store._messages = {}

---@param message LlmMessage
Store.register_message = function(message)
  -- First message
  if #Store._messages == 0 then
    table.insert(Store._messages, message)
    return
  end

  local last_message = Store._messages[#Store._messages]

  -- If the most recent message is not from the user, then we'll assume the llm is in the process of giving a response.
  -- User messages never come in piecemeal.
  if last_message.role == "assistant" and message.role == "assistant" then
    last_message.content = last_message.content .. message.content
  else
    table.insert(Store._messages, message)
  end
end

Store.get_messages = function()
  return Store._messages
end

Store.clear_messages = function()
  Store._messages = {}
end

---@param job Job
---@return nil
Store.register_job = function(job)
  Store._job = job
end

---@return Job | nil
Store.get_job = function()
  return Store._job
end

Store.clear_job = function()
  Store._job = nil
end

return Store
