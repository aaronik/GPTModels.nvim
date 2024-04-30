-- Weird quirk of this file is you don't need to require() it in nvim, you just
-- need to have the file open in some buffer

---@class LlmMessage
---@field role string
---@field content string

---@class LlmGenerateArgs
---@field model string | nil
---@field stream boolean
---@field prompt string

---@class MakeGenerateRequestArgs
---@field llm LlmGenerateArgs
---@field on_response fun(response: string)
---@field on_end function | nil
---@field on_error fun(message: string) | nil

---@class LlmChatArgs
---@field model string | nil
---@field stream boolean
---@field messages LlmMessage[] | nil

---@class MakeChatRequestArgs
---@field llm LlmChatArgs
---@field on_response fun(message: LlmMessage)
---@field on_end function | nil
---@field on_error fun(message: string) | nil



