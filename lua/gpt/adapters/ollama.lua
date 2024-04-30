local util = require('gpt.util')
local job = require('plenary.job')
require('gpt.types')

local M = {}

-- curl http://localhost:11434/api/chat -d '{ "model": "llama2", "messages": [ { "role": "user", "content": "why is the sky blue?" } ] }'

---@param args MakeGenerateRequestArgs
---@return { shutdown: function }
M.generate = function(args)
    local url = "http://localhost:11434/api/generate"

    local curl_args = {
        url,
        "--data",
        -- vim.fn.json_encode(args.llm)
        vim.fn.json_encode(args.llm)
    }

    job
        :new({
            command = "curl",
            args = curl_args,
            on_stdout = vim.schedule_wrap(function(_, json)
                if json then
                    local data = vim.fn.json_decode(json) or { response = "JSON decode error for LLM response!" }
                    args.on_response(data.response) -- for generate
                end
            end),
            on_stderr = vim.schedule_wrap(function(error, data, self)
                -- This gives the curl status stuff, not errors. Library is broken.
                -- TODO Figure this out and call on_error with data if it's not nil
            end),
            on_exit = vim.schedule_wrap(function()
                if args.on_end ~= nil then
                    args.on_end()
                end
            end)
        })
        :start()

    return job
end

---@param args MakeChatRequestArgs
---@return { shutdown: function }
M.chat = function(args)
    local url = "http://localhost:11434/api/chat"

    local curl_args = {
        url,
        "--data",
        -- vim.fn.json_encode(args.llm)
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
                    args.on_response(data.message) -- for chat
                end
            end),
            on_stderr = vim.schedule_wrap(function(error, data, self)
                -- This gives the curl status stuff, not errors. Library is broken.
                -- TODO Figure this out and call on_error with data if it's not nil
            end),
            -- TODO Test that this doesn't throw when on_end isn't passed in
            on_exit = vim.schedule_wrap(function()
                if args.on_end ~= nil then
                    args.on_end()
                end
            end)
        })
        :start()

    return job
end

return M
