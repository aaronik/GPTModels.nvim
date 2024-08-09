local util = require('gptmodels.util')
local cmd = require('gptmodels.cmd')
require('gptmodels.types')

local M = {}

-- curl http://localhost:11434/api/chat -d '{ "model": "llama2", "messages": [ { "role": "user", "content": "why is the sky blue?" } ] }'

---@param args MakeGenerateRequestArgs
---@return Job
M.generate = function(args)
    local url = "http://localhost:11434/api/generate"

    -- default model
    if not args.llm.model then
        args.llm.model = "llama3.1"
    end

    -- system prompt
    if args.llm.system then
        ---@diagnostic disable-next-line: assign-type-mismatch -- do some last minute munging to get it happy for ollama
        args.llm.system = table.concat(args.llm.system, "\n\n")
    end

    local curl_args = {
        url,
        "--data",
        vim.fn.json_encode(args.llm),
        "--no-progress-meter",
        "--no-buffer",
    }

    local job = cmd.exec({
        testid = "ollama-generate",
        cmd = "curl",
        args = curl_args,
        onread = vim.schedule_wrap(function(err, json)
            if err then return args.on_read(err) end
            if not json then return end

            -- There's a final message that ollama returns, which sometimes is
            -- too big for a single curl frame response. So the json can't get
            -- decoded.
            -- The first always contains "done": true
            if string.match(json, '"done":true') then
                return
            end

            -- The rest start with a comma or a number.
            local pattern = "^[%,%d]"
            if string.match(json, pattern) then
                return
            end

            ---@type boolean, { response: string } | nil
            local status_ok, data = pcall(vim.fn.json_decode, json)
            if not status_ok or not data then
                return args.on_read("Error decoding json: " .. json, "")
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

    if not args.llm.model then
        args.llm.model = "llama3.1"
    end

    local curl_args = {
        url,
        "--data",
        vim.fn.json_encode(args.llm),
        "--no-progress-meter",
        "--no-buffer",
    }

    local job = cmd.exec({
        testid = "ollama-chat",
        cmd = "curl",
        args = curl_args,
        onread = vim.schedule_wrap(function(err, json)
            if err then return args.on_read(err) end
            if not json then return end

            -- There's a final message that ollama returns, which sometimes is
            -- too big for a single curl frame response. So the json can't get
            -- decoded.
            -- The first always contains "done": true
            if string.match(json, '"done":true') then
                return
            end

            -- The rest start with a comma or a number.
            local pattern = "^[%,%d]"
            if string.match(json, pattern) then
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
        cmd = "curl",
        args = { "--no-progress-meter", "http://localhost:11434/api/tags" },
        ---@param err string | nil
        ---@param json_response string | nil
        onread = vim.schedule_wrap(function(err, json_response)
            if err then return cb(err) end
            if not json_response then return end

            ---@type boolean, { models: { name: string }[] } | nil
            local status_ok, response = pcall(vim.fn.json_decode, json_response)
            if not status_ok or not response then
                return cb("error retrieving ollama models")
            end

            ---@type string[]
            local models = {}

            for _, model in ipairs(response.models) do
                table.insert(models, model.name)
            end

            return cb(nil, models)
        end)
    })

    return job
end

return M
