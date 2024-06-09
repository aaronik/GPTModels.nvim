---@class LlmMessage
---@field role string
---@field content string

---@class LlmGenerateArgs
---@field system string[] | nil
---@field model string | nil
---@field stream boolean
---@field prompt string

---@class LlmChatArgs
---@field system string | nil
---@field model string | nil
---@field stream boolean
---@field messages LlmMessage[] | nil

---@class MakeGenerateRequestArgs
---@field llm LlmGenerateArgs
---@field on_read fun(err: string | nil, response: string | nil)
---@field on_end function | nil

---@class MakeChatRequestArgs
---@field llm LlmChatArgs
---@field on_read fun(err: string | nil, message: LlmMessage | nil)
---@field on_end function | nil

---@class Job
---@field handle uv_process_t | nil
---@field pid string | integer
---@field die function
---@field done fun():boolean

---@alias TestIds
---| "ollama-generate"
---| "ollama-chat"

---@class ExecArgs
---@field cmd string
---@field args string[] | nil
---@field onread fun(err: string | nil, data: string | nil) | nil
---@field onexit fun(code: integer, signal: integer) | nil
---@field sync boolean | nil
---@field testid TestIds | nil
