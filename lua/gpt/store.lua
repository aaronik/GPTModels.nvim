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
---@field clear fun(self: StrPane | LinesPane | MessagePane)
---@field popup NuiPopup

---@class StrPane : Pane
---@field append fun(self: StrPane, text: string)
---@field read fun(self: StrPane): string | nil
---@field private _text string

---@class LinesPane : Pane
---@field append fun(self: LinesPane, lines: string[])
---@field read fun(self: LinesPane): string[] | nil
---@field private _lines string[]

---@class MessagePane : Pane
---@field append fun(self: MessagePane, message: LlmMessage)
---@field read fun(self: MessagePane): LlmMessage[]
---@field private _messages LlmMessage[]

---@class Window
---@field clear fun(self: ChatWindow | CodeWindow)
---@field input StrPane
---@field append_file fun(self: Window, filename: string)
---@field get_files fun(self: Window): string[]
---@field clear_files fun(self: Window)
---@field private _files string[]

---@class CodeWindow : Window
---@field right StrPane
---@field left StrPane

---@class ChatWindow : Window
---@field chat MessagePane

---@class Store
---@field clear fun(self: Store)
---@field code CodeWindow
---@field chat ChatWindow
---@field register_job fun(self: Store, job: Job)
---@field get_job fun(self: Store): Job | nil
---@field clear_job fun(self: Store)
---@field llm_models { openai: string[], ollama: string[] }
---@field llm_provider string
---@field llm_model string
---@field set_llm fun(self: Store, provider: "openai" | "ollama", model: string)
---@field private _job Job | nil

-- TODO store should store lines (string[]) instead of string. More neovim centric data structure. Less munging.

---@return StrPane
local function build_strpane()
  ---@type StrPane
  return {
    _text = "",
    append = function(self, text) self._text = self._text .. text end,
    read = function(self) return self._text end,
    clear = function(self) self._text = "" end
  }
end

---@type Store
local Store = {
  llm_models = {
    openai = { "gpt-4-turbo", "gpt-3.5-turbo" },
    ollama = { "llama3", "mistral" },
  },
  llm_provider = "ollama",
  llm_model = "llama3",

  set_llm = function(self, provider, model)
    self.llm_provider = provider
    self.llm_model = model
  end,

  clear = function(self)
    self.code:clear()
    self.chat:clear()
  end,

  code = {
    right = build_strpane(),
    left = build_strpane(),
    input = build_strpane(),

    _files = {},
    append_file = function(self, filename) table.insert(self._files, filename) end,
    get_files = function(self) return self._files end,
    clear_files = function(self) self._files = {} end,

    clear = function(self)
      self.right:clear()
      self.left:clear()
      self.input:clear()
      self:clear_files()
    end
  },
  chat = {
    input = build_strpane(),

    chat = {
      _messages = {},
      read = function(self) return self._messages end,
      append = function(self, message) concat_chat(self._messages, message) end,
      clear = function(self) self._messages = {} end
    },

    _files = {},
    append_file = function(self, filename) table.insert(self._files, filename) end,
    get_files = function(self) return self._files end,
    clear_files = function(self) self._files = {} end,

    clear = function(self)
      self.input:clear()
      self.chat:clear()
      self:clear_files()
    end
  },

  register_job = function(self, job) self._job = job end,
  get_job = function(self) return self._job end,
  clear_job = function(self) self._job = nil end

}

return Store
