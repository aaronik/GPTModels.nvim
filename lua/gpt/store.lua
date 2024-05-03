---@param chat LlmMessage
---@param message LlmMessage
local concat_chat = function(chat, message)
  -- If this is the first message of the session
  if #chat == 0 then
    table.insert(chat, message)
    return
  end

  local last_message = chat[#chat]

  -- If the most recent message is not from the user, then it's assumed the llm is  giving a response.
  -- User messages never come in piecemeal.
  if last_message.role == "assistant" and message.role == "assistant" then
    last_message.content = last_message.content .. message.content
  else
    table.insert(chat, message)
  end
end

local Store = {}
Store = {
  edit = {
    _right = "",
    right = {
      ---@param text string
      append = function(text) Store.edit._right = Store.edit._right .. text end,
      read = function() return Store.edit._right end,
    },

    _left = "",
    left = {
      ---@param text string
      append = function(text) Store.edit._left = Store.edit._left .. text end,
      read = function() return Store.edit._left end,
    },

    _input = "",
    input = {
      ---@param text string
      append = function(text) Store.edit._input = Store.edit._input .. text end,
      read = function() return Store.edit._input end,
    },

    clear = function()
      Store.edit._right = ""
      Store.edit._left = ""
      Store.edit._input = ""
    end
  },
  chat = {
    _input = "",
    input = {
      ---@param text string
      append = function(text) Store.chat._input = Store.chat._input .. text end,
      read = function() return Store.chat._input end,
    },

    ---@type LlmMessage[]
    _chat = {},
    chat = {
      read = function() return Store.chat._chat end,
      ---@param message LlmMessage
      append = function(message) concat_chat(Store.chat._chat, message) end,
    },

    clear = function()
      Store.chat._input = ""
      Store.chat._chat = {}
    end
  },
}


-- Jobs --

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

-- Sessions --

return Store
