local util = require('gpt.util')
local cmd = require('gpt.cmd')
require('gpt.types')

local M = {}

-- curl http://localhost:11434/api/chat -d '{ "model": "llama2", "messages": [ { "role": "user", "content": "why is the sky blue?" } ] }'

---@param args MakeGenerateRequestArgs
---@return Job
M.generate = function(args)
    local url = "http://localhost:11434/api/generate"

    local curl_args = {
        url,
        "--silent",
        "--data",
        vim.fn.json_encode(args.llm),
        "--no-buffer",
    }

    local job = cmd.exec({
        cmd = "curl",
        args = curl_args,
        onread = vim.schedule_wrap(function(err, json)
            if err then error(err) end
            if not json then return end

            local status_ok, data = pcall(vim.fn.json_decode, json)
            if not status_ok or not data then
                error("Error getting json TODO better this" .. json)
            end
            args.on_read(nil, data.response)
        end),
        onexit = vim.schedule_wrap(function()
            if args.on_end ~= nil then
                args.on_end()
            end
        end)
    })

    return job
end

---@param args MakeChatRequestArgs
---@return Job
M.chat = function(args)
    local url = "http://localhost:11434/api/chat"

    local curl_args = {
        url,
        "--silent",
        "--data",
        vim.fn.json_encode(args.llm),
        "--no-buffer",
    }

    local job = cmd.exec({
        cmd = "curl",
        args = curl_args,
        onread = vim.schedule_wrap(function(err, json)
            if err then error(err) end
            if not json then return end

            local json_lines = vim.split(json, "\n", { trimempty = true })

            for _, line in ipairs(json_lines) do
                local status_ok, data = pcall(vim.fn.json_decode, line)
                if not status_ok or not data then
                    data = { message = { role = "assistant", content = "JSON decode error for LLM response!  " .. json } }
                    -- error("error decoding LLM json: " .. line)
                end
                -- data is large, data.resposne is the text we're looking for
                args.on_read(nil, data.message) -- for chat
            end
        end),
        -- TODO Test that this doesn't throw when on_end isn't passed in
        onexit = vim.schedule_wrap(function()
            if args.on_end then
                args.on_end()
            end
        end)
    })

    return job
end

return M
