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

---@class ExecArgs
---@field cmd string
---@field args string[] | nil
---@field onread fun(err: string | nil, data: string | nil) | nil
---@field onexit fun(code: integer, signal: integer) | nil
---@field sync boolean | nil

---@class NuiBorder
---@field set_text fun(self: NuiBorder, edge: "top" | "bottom" | "left" | "right", text: string, align: "left" | "right" | "center")

-- Wish they exported types
---@class NuiPopup
---@field bufnr integer
---@field winid integer | nil
---@field border NuiBorder
---@field on fun(self: NuiPopup, vim_event: string, function)
