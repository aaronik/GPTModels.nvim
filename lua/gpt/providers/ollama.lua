local util = require('gpt.util')
local cmd = require('gpt.cmd')
require('gpt.types')

local M = {}

-- curl http://localhost:11434/api/chat -d '{ "model": "llama2", "messages": [ { "role": "user", "content": "why is the sky blue?" } ] }'

---@param args MakeGenerateRequestArgs
---@return Job
M.generate = function(args)
    local url = "http://localhost:11434/api/generate"

    if not args.llm.model then
        args.llm.model = "llama3"
    end

    if args.llm.system then
        ---@diagnostic disable-next-line: assign-type-mismatch -- do some last minute munging to get it happy for ollama
        args.llm.system = table.concat(args.llm.system, "\n\n")
    end

    local curl_args = {
        url,
        "--data",
        vim.fn.json_encode(args.llm),
        "--silent",
        "--no-buffer",
    }

    local job = cmd.exec({
        cmd = "curl",
        args = curl_args,
        onread = vim.schedule_wrap(function(err, json)
            if err then return args.on_read(err) end
            if not json then return end

            -- A strange case where a final message returned by ollama often has a decoding issue,
            -- but doesn't have any content. So it's getting dropped
            if string.match(json, '"done":true') then
                return
            end

            ---@type boolean, { response: string } | nil
            local status_ok, data = pcall(vim.fn.json_decode, json)
            if not status_ok or not data then
                args.on_read("Error decoding json: " .. json, "")
            end

            ---@diagnostic disable-next-line: need-check-nil
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

    if not args.llm.model then
        args.llm.model = "llama3"
    end

    local curl_args = {
        url,
        "--data",
        vim.fn.json_encode(args.llm),
        "--silent",
        "--no-buffer",
    }

    local job = cmd.exec({
        cmd = "curl",
        args = curl_args,
        onread = vim.schedule_wrap(function(err, json)
            if err then return args.on_read(err) end
            if not json then return end

            -- A strange case where a final message returned by ollama often has a decoding issue,
            -- but doesn't have any content. So it's getting dropped
            if string.match(json, '"done":true') then
                return
            end

            -- split, and trim empty lines
            local json_lines = vim.split(json, "\n")
            json_lines = vim.tbl_filter(function(line) return line ~= "" end, json_lines)

            for _, line in ipairs(json_lines) do
                local status_ok, data = pcall(vim.fn.json_decode, line)
                if not status_ok or not data then
                    return args.on_read("JSON decode error for LLM response!  " .. json)
                end

                args.on_read(nil, data.message)
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

---@param cb fun(err: string | nil, models: string[] | nil)
---@return Job
M.fetch_models = function(cb)
    local job = cmd.exec({
        cmd = "ollama",
        args = { "list" },
        ---@param err string | nil
        ---@param response string | nil
        onread = vim.schedule_wrap(function(err, response)
            if err then return cb(err) end
            if not response then return end

            local models = {}
            for line in response:gmatch("[^\r\n]+") do
                -- drop the first line, which just has column names
                if not line:match("%s*NAME.*") then
                    local name = line:match("^%s*(.-)%s+%S+")
                    if name then
                        table.insert(models, name)
                    end
                end
            end

            return cb(nil, models)
        end)
    })

    return job
end

return M
