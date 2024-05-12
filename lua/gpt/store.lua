-- I want to use private/protected for _right, _input etc, but am not finding a way to make that play nice with this file.
-- I really just want those _ prefixed fields to not be typewise accessible outside of this module.
---@diagnostic disable: invisible

---@param chat LlmMessage[]
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

---@class Pane
---@field clear fun()
---@field bufnr integer | nil
---@field winid integer | nil

---@class StrPane : Pane
---@field append fun(text: string)
---@field read fun(): string | nil

---@class MessagePane : Pane
---@field append fun(message: LlmMessage)
---@field read fun(): LlmMessage[]

---@class CodeWindow
---@field clear fun()
---@field right StrPane
---@field left StrPane
---@field input StrPane
---@field private _right string
---@field private _left string
---@field private _input string

---@class ChatWindow
---@field clear fun()
---@field input StrPane
---@field chat MessagePane
---@field private _input string
---@field private _chat LlmMessage[]

---@class Store
---@field clear fun()
---@field code CodeWindow
---@field chat ChatWindow
---@field register_job fun(job: Job)
---@field get_job fun(): Job | nil
---@field clear_job fun()
---@field llm_models { openai: string[], ollama: string[] }
---@field llm_provider string
---@field llm_model string
---@field set_llm fun(provider: "openai" | "ollama", model: string)
---@field private _job Job | nil


---@type Store
local Store
Store = {
  -- TODO: I can show the user a vertical list of options like openai.gpt-4-turbo, ollama.llama3, etc
  llm_models = {
    openai = { "gpt-4-turbo", "gpt-3.5-turbo" },
    ollama = { "llama3", "mistral" },
  },
  llm_provider = "openai",
  llm_model = "gpt-4-turbo",

  set_llm = function (provider, model)
    Store.llm_provider = provider
    Store.llm_model = model
  end,

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
      append = function(text) Store.chat._input = Store.chat._input .. text end,
      read = function() return Store.chat._input end,
      clear = function() Store.chat._input = "" end
    },

    _chat = {},
    chat = {
      read = function() return Store.chat._chat end,
      append = function(message) concat_chat(Store.chat._chat, message) end,
      clear = function() Store.chat._chat = {} end
    },

    clear = function()
      Store.chat.input.clear()
      Store.chat.chat.clear()
    end
  },

  register_job = function(job)
    Store._job = job
  end,

  get_job = function()
    return Store._job
  end,

  clear_job = function()
    Store._job = nil
  end

}

return Store
