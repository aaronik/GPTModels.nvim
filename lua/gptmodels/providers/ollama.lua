local util = require('gptmodels.util')
local cmd = require('gptmodels.cmd')
local consts = require('gptmodels.constants')
require('gptmodels.types')

-- curl http://localhost:11434/api/chat -d '{ "model": "llama2", "messages": [ { "role": "user", "content": "why is the sky blue?" } ] }'

-- TODO: How to get the LSP to recognize this file to have 2 spaces instead of 4? Why's it work fine in Store but not here?

-- TODO When a model is not present, this response comes down. Need to check for error and
-- {"error":"model \"nooooooop\" not found, try pulling it first"}

---@type LlmProvider
local Provider = {
    name = 'ollama',
    generate = function(args)
        local url = "http://localhost:11434/api/generate"

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

        local json_fragment_aggregate = ''

        local job = cmd.exec({
            testid = "ollama-generate",
            cmd = "curl",
            args = curl_args,
            onread = vim.schedule_wrap(function(err, json_fragment)
                if err then return args.on_read(err) end
                if not json_fragment then return end -- TODO return args.on_read()

                -- TODO Abstract this similar json aggregation logic into shared lib
                json_fragment_aggregate = json_fragment_aggregate .. json_fragment

                local status_ok, data = pcall(vim.fn.json_decode, json_fragment_aggregate)
                if not status_ok or not data then
                    return -- wait for another fragment to come in
                end

                json_fragment_aggregate = '' -- the fragments were fully combined, reset the aggregate
                args.on_read(nil, data.response)
            end),
            onexit = vim.schedule_wrap(function()
                -- TODO return error when there's leftover json_fragment_aggregate here and below
                if args.on_end ~= nil then
                    args.on_end()
                end
            end)
        })

        return job
    end,

    chat = function(args)
        local url = "http://localhost:11434/api/chat"

        local curl_args = {
            url,
            "--data",
            vim.fn.json_encode(args.llm),
            "--no-progress-meter",
            "--no-buffer",
        }

        local json_fragment_aggregate = ''

        local job = cmd.exec({
            testid = "ollama-chat",
            cmd = "curl",
            args = curl_args,
            onread = vim.schedule_wrap(function(err, json_fragment)
                if err then return args.on_read(err) end
                if not json_fragment then return end

                -- split, and trim empty lines
                local json_lines = vim.split(json_fragment, "\n")
                json_lines = vim.tbl_filter(function(line) return line ~= "" end, json_lines)

                for _, line in ipairs(json_lines) do
                    line = json_fragment_aggregate .. line
                    local status_ok, data = pcall(vim.fn.json_decode, line)
                    if status_ok and data then
                        json_fragment_aggregate = ''
                        args.on_read(nil, data.message)
                    else
                        json_fragment_aggregate = line
                    end
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
    end,

    fetch_models = function(cb)
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
}

return Provider
