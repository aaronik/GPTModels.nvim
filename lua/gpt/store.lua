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
  if last_message.role ~= "user" then
    last_message.content = last_message.content .. message.content
  elseif last_message.role == "user" then
    table.insert(Store._messages, message)
  end
end

Store.get_messages = function()
  return Store._messages
end

return Store
