local job = require('plenary.job')

local M = {}

---@param prompt string
---@param model string
---@param on_response fun(response: string)
---@param on_end function
---@param on_error fun(message: string)
---@param stream boolean
---@return nil
M.make_request = function(prompt, model, on_response, on_end, on_error, stream)
    local args = {
        "http://localhost:11434/api/generate",
        "-d",
        vim.fn.json_encode({ model = model, prompt = prompt, stream = stream })
    }

    job
        :new({
            command = "curl",
            args = args,
            on_stdout = vim.schedule_wrap(function(_, json)
                if json then
                    local data = vim.fn.json_decode(json) or { response = "JSON decode error for LLM response!"}
                    -- data is large, data.resposne is the text we're looking for
                    on_response(data.response)
                end
            end),
            -- TODO Test
            on_stderr = vim.schedule_wrap(function(_)
                on_error("TODO whoops")
            end),
            on_exit = vim.schedule_wrap(function()
                on_end()
            end)
        })
        :start()
end

return M
