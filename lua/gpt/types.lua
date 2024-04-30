---@class LlmMessage
---@field role string
---@field content string

---@class LlmArgs
---@field prompt string
---@field model string | nil
---@field stream boolean
---@field messages LlmMessage[] | nil

---@class MakeRequestArgs
---@field llm LlmArgs
---@field kind "generate" | "chat"
---@field on_response fun(response: string)
---@field on_end function | nil
---@field on_error fun(message: string) | nil


