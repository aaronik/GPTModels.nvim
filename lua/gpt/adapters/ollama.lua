local util = require('gpt.util')
local job = require('plenary.job')
require('gpt.types')

local M = {}

-- curl http://localhost:11434/api/chat -d '{ "model": "llama2", "messages": [ { "role": "user", "content": "why is the sky blue?" } ] }'

---@param args MakeGenerateRequestArgs
---@return Job
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
---@return Job
M.chat = function(args)
    local url = "http://localhost:11434/api/chat"

    local curl_args = {
        url,
        "--data",
        vim.fn.json_encode(args.llm)
    }

    job
        :new({
            command = "curl",
            args = curl_args,
            on_stdout = vim.schedule_wrap(function(_, json, self)
                -- TODO The ish: shutdown() doesn't work, self:pid() is recursive and breaks, I want pid to be on job.
                -- I'd rather it happen at the beginning of job instantiation though, than on first response / error.
                -- Luckily, curl immediately starts writing to stdout with the status bar, which unfortunately plenary.job
                -- interprets as stderr.
                -- This is hacks upon hacks upon hacks. I think we need to ditch plenary.job, or fix it.
                job.my_pid = self.pid
                if json then
                    local data = vim.fn.json_decode(json) or { response = "JSON decode error for LLM response!" }
                    -- data is large, data.resposne is the text we're looking for
                    args.on_response(data.message) -- for chat
                end
            end),
            on_stderr = vim.schedule_wrap(function(error, data, self)
                job.my_pid = self.pid
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

    -- util.log(job:pid())
    -- util.log(job.my_pid)

    return job
end

return M
