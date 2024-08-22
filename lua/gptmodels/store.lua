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

-- Finds the index of the model/provider pair where model == provider
---@param model_options { model: string, provider: string }[]
---@param provider string
---@param model string
---@return integer | nil
local function find_model_index(model_options, provider, model)
  for index, option in ipairs(model_options) do
    if option.provider == provider and option.model == model then
      return index
    end
  end
  return nil -- No match found
end

---@param self Store
local function build_model_options(self)
  ---@type { model: string, provider: string }[]
  local model_options = {}
  for provider, models in pairs(self._llm_models) do
    for _, model in ipairs(models) do
      table.insert(model_options, { provider = provider, model = model })
    end
  end
  return model_options
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

---@alias Provider "openai" | "ollama"

---@class Store
---@field clear fun(self: Store)
---@field code CodeWindow
---@field chat ChatWindow
---@field register_job fun(self: Store, job: Job)
---@field get_job fun(self: Store): Job | nil
---@field clear_job fun(self: Store)
---@field private _llm_models { openai: string[], ollama: string[] }
---@field get_models fun(self: Store, provider: Provider): string[]
---@field set_models fun(self: Store, provider: Provider, models: string[])
---@field get_model fun(self: Store): { provider: string, model: string }
---@field set_model fun(self: Store, provider: Provider, model: string)
---@field llm_model_strings fun(self: Store): string[] -- TODO This doesn't belong here, it's a store utility. Maybe just somewhere else in this file.
---@field private _llm_provider string
---@field private _llm_model string
---@field cycle_model_forward fun(self: Store)
---@field cycle_model_backward fun(self: Store)
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
  _llm_models = {
    openai = { "gpt-4-turbo", "gpt-3.5-turbo", "gpt-4o", "gpt-4o-mini" },
    ollama = { "llama3.1:latest" },
  },

  _llm_provider = "ollama",
  _llm_model = "llama3.1:latest",

  -- model accessor
  get_model = function(self)
    return { provider = self._llm_provider, model = self._llm_model }
  end,

  -- set the active model
  set_model = function(self, provider, model)
    self._llm_provider = provider
    self._llm_model = model
  end,

  -- get all models for a provider
  get_models = function(self, provider)
    return self._llm_models[provider]
  end,

  -- set all models for a provider, overwriting previous values
  set_models = function(self, provider, models)
    self._llm_models[provider] = models
  end,

  cycle_model_forward = function(self)
    local model_options = build_model_options(self)
    local current_index = find_model_index(model_options, self._llm_provider, self._llm_model)
    if not current_index then current_index = #model_options end
    local selected_option = model_options[(current_index % #model_options) + 1]
    self:set_model(selected_option.provider, selected_option.model)
  end,

  cycle_model_backward = function(self)
    local model_options = build_model_options(self)
    local current_index = find_model_index(model_options, self._llm_provider, self._llm_model)
    if not current_index then current_index = 1 end
    local selected_option = model_options[(current_index - 2) % #model_options + 1]
    self:set_model(selected_option.provider, selected_option.model)
  end,

  -- TODO Get rid of this, only used once in common. Just inline it.
  llm_model_strings = function(self)
    local model_strings = {}
    for provider, models in pairs(self._llm_models) do
      for _, model in ipairs(models) do
        table.insert(model_strings, provider .. "." .. model)
      end
    end
    return model_strings
  end,

  clear = function(self)
    self.code:clear()
    self.chat:clear()
    self:set_models("ollama", {})
    self:set_models("openai", {})
    -- TODO Need to clear default model as well?
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
