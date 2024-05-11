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

-- TODO type this thing
local Store = {}
Store = {
  clear = function()
    Store.code.clear()
    Store.chat.clear()
  end,

  code = {
    _right = "",
    right = {
      -- NOTE: If this pattern becomes useful, make it nicer. Right now it's like an unofficial hack.
      ---@type integer | nil
      bufnr = nil,

      ---@param text string
      append = function(text) Store.code._right = Store.code._right .. text end,
      read = function() return Store.code._right end,
      clear = function() Store.code._right = "" end
    },

    _left = "",
    left = {
      ---@param text string
      append = function(text) Store.code._left = Store.code._left .. text end,
      read = function() return Store.code._left end,
      clear = function() Store.code._left = "" end
    },

    _input = "",
    input = {
      ---@param text string
      append = function(text) Store.code._input = Store.code._input .. text end,
      read = function() return Store.code._input end,
      clear = function() Store.code._input = "" end
    },

    clear = function()
      Store.code.right.clear()
      Store.code.left.clear()
      Store.code.input.clear()
    end
  },
  chat = {
    _input = "",
    input = {
      ---@param text string
      append = function(text) Store.chat._input = Store.chat._input .. text end,
      read = function() return Store.chat._input end,
      clear = function() Store.chat._input = "" end
    },

    ---@type LlmMessage[]
    _chat = {},
    chat = {
      read = function() return Store.chat._chat end,
      ---@param message LlmMessage
      append = function(message) concat_chat(Store.chat._chat, message) end,
      clear = function() Store.chat._chat = {} end
    },

    clear = function()
      Store.chat.input.clear()
      Store.chat.chat.clear()
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
