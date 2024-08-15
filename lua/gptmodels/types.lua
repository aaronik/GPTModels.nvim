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

---@class NuiBorder
---@field set_text fun(self: NuiBorder, edge: "top" | "bottom" | "left" | "right", text: string, align: "left" | "right" | "center")

---@class LlmProvider
---@field name string
---@field generate fun(args: MakeGenerateRequestArgs): Job
---@field chat fun(args: MakeChatRequestArgs): Job
---@field fetch_models fun(cb: fun(err: string | nil, models: string[] | nil)): Job

-- TODO Rename text to lines
---@class Selection
---@field start_line number
---@field end_line number
---@field start_column number
---@field end_column number
---@field text string[]


-- -- Wish they exported types
-- -- Update: At some point it appears they did, but later I'm having trouble finding them.
-- -- LSP is not picking it up any more, but often requires file to be open before registering
-- -- types definted in it.
-- -- TODO: This is at risk of divergence from the actual NuiPopup. Gotta find that again.
-- ---@class NuiPopup
-- ---@field bufnr integer
-- ---@field winid integer | nil
-- ---@field border NuiBorder
-- ---@field on fun(self: NuiPopup, vim_event: string, function)

