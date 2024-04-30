local job = require('plenary.job')
require('gpt.types')

local M = {}

---@param args MakeRequestArgs
---@return nil
M.make_request = function(args)
    local curl_args = {
        "http://localhost:11434/api/generate",
        "--data",
        vim.fn.json_encode(args.llm)
    }

    job
        :new({
            command = "curl",
            args = curl_args,
            on_stdout = vim.schedule_wrap(function(_, json)
                if json then
                    local data = vim.fn.json_decode(json) or { response = "JSON decode error for LLM response!" }
                    -- data is large, data.resposne is the text we're looking for
                    args.on_response(data.response)
                end
            end),
            -- TODO Test
            on_stderr = vim.schedule_wrap(function(_)
                args.on_error("TODO whoops")
            end),
            on_exit = vim.schedule_wrap(function()
                args.on_end()
            end)
        })
        :start()
end

return M
