local util = require('gptmodels.util')
local cmd = require('gptmodels.cmd')
local consts = require('gptmodels.constants')
require('gptmodels.types')

-- TODO sometimes openai will return an error in a response, ex:
-- {
--     "error": {
--         "message": "The model `nooooooop` does not exist or you do not have access to it.",
--         "type": "invalid_request_error",
--         "param": null,
--         "code": "model_not_found"
--     }
-- }
-- This needs to be handled aka passed back up

-- curl -X POST -H "Authorization: Bearer $OPENAI_API_KEY" -H "Content-Type: application/json" -d '{
--   "model": "gpt-4-turbo",
--   "messages": [{ "role": "user", "content": "Translate this text into French: Hello, world!" }]
-- }' https://api.openai.com/v1/chat/completions

-- Both endpoints will use the same onread, since it's actually the same endpoint for openai
---@param response string
---@return string | nil, LlmMessage[] | nil
local parse_llm_response = function(response)
    -- replace \r\n with just \n
    response = string.gsub(response, "\r\n", "\n")

    -- Break on newlines, remove empty lines
    local json_lines = vim.split(response, "\n")
    json_lines = vim.tbl_filter(function(line) return line ~= "" end, json_lines)

    -- Then, for some reason all their lines start with data: . Just the string, not json. Weird.
    for i, line in ipairs(json_lines) do
        if line:sub(1, 5) == "data:" then
            json_lines[i] = line:sub(7)
        end
    end

    ---@type LlmMessage[]
    local messages = {}

    for _, line in ipairs(json_lines) do
        -- openai will return this as its own line for some reason
        if line == '[DONE]' or line == "" then
            break
        end

        -- Just return the error.
        ---@type boolean, { choices: { delta: LlmMessage }[] } | nil
        local status_ok, data = pcall(vim.fn.json_decode, line)
        if not status_ok or not data or not data.choices or not data.choices[1].delta then
            -- TODO this seems untested
            return consts.LLM_DECODE_ERROR_STRING .. line .. ":\n" .. vim.inspect(data) .. "\n\n"
        end

        if not data.choices[1].delta.role then
            data.choices[1].delta.role = "assistant"
        end

        if not data.choices[1].delta.content then
            data.choices[1].delta.content = ""
        end

        table.insert(messages, data.choices[1].delta)
    end

    return nil, messages
end


---@type LlmProvider
local Provider = {
    name = 'openai',

    generate = function(args)
        local url = "https://api.openai.com/v1/chat/completions"

        if not args.llm.model then
            args.llm.model = "gpt-4-turbo"
        end

        -- openai changes their stuff around a bit, and now there's no prompt, only messages
        ---@type LlmMessage[]
        ---@diagnostic disable-next-line: inject-field
        args.llm.messages = {
            { role = "user", content = args.llm.prompt }
        }

        for _, system_string in ipairs(args.llm.system or {}) do
            table.insert(args.llm.messages, {
                role = "system",
                content = system_string
            })
        end

        args.llm.prompt = nil
        args.llm.system = nil

        local curl_args = {
            url,
            "--data",
            vim.fn.json_encode(args.llm),
            "-H",
            "Authorization: Bearer " .. os.getenv("OPENAI_API_KEY"),
            "-H",
            "Content-Type: application/json",
            "--no-progress-meter",
            "--no-buffer",
        }

        local response_aggregate = ''

        local job = cmd.exec({
            cmd = "curl",
            args = curl_args,
            onread = vim.schedule_wrap(function(err, response)
                if err then return args.on_read(err, nil) end
                if not response then return end

                response = response_aggregate .. response

                local parse_error, messages = parse_llm_response(response)

                if parse_error then
                    response_aggregate = response
                end

                if not messages then
                    return
                end

                response_aggregate = ''
                for _, message in ipairs(messages) do
                    args.on_read(nil, message.content)
                end
            end),
            onexit = vim.schedule_wrap(function()
                if args.on_end ~= nil then
                    args.on_end()
                end
            end)
        })

        return job
    end,

    chat = function(args)
        local url = "https://api.openai.com/v1/chat/completions"

        -- TODO remove this and rely on store's automatic defaults
        if not args.llm.model then
            args.llm.model = "gpt-4-turbo"
        end

        local curl_args = {
            url,
            "--data",
            vim.fn.json_encode(args.llm),
            "-H",
            "Authorization: Bearer " .. os.getenv("OPENAI_API_KEY"),
            "-H",
            "Content-Type: application/json",
            "--no-buffer",
            "--no-progress-meter",
        }

        local response_aggregate = ''

        local job = cmd.exec({
            cmd = "curl",
            args = curl_args,
            onread = vim.schedule_wrap(function(err, response)
                if err then return args.on_read(err, nil) end
                if not response then return end

                response = response_aggregate .. response

                local parse_error, messages = parse_llm_response(response)

                if parse_error then
                    -- return args.on_read(parse_error)
                    response_aggregate = response
                end

                if not messages then
                    return
                end

                for _, message in ipairs(messages) do
                    args.on_read(nil, message)
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
        error("openai model fetching not yet implemented")
    end
}

return Provider
