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
    response = string.gsub(response, "\r\n", "\n")

    -- Break on newlines, remove empty lines
    local json_lines = vim.split(response, "\n")
    json_lines = vim.tbl_filter(function(line) return line ~= "" end, json_lines)

    -- All their lines start with data: . Just the string, not in json
    for i, line in ipairs(json_lines) do
        if line:sub(1, 5) == "data:" then
            json_lines[i] = line:sub(7)
        end
    end

    ---@type LlmMessage[]
    local messages = {}

    for _, line in ipairs(json_lines) do
        -- openai will return this as its own line
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

        -- openai changed their stuff around a bit, and now there's no prompt, only messages
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
            "Authorization: Bearer " .. (os.getenv("OPENAI_API_KEY") or ""),
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
        local openai_api_key = os.getenv("OPENAI_API_KEY") or ""

        local curl_args = {
            url,
            "--data",
            vim.fn.json_encode(args.llm),
            "-H",
            "Authorization: Bearer " .. openai_api_key,
            "-H",
            "Content-Type: application/json",
            "--no-buffer",
            "--no-progress-meter",
        }

        -- For clipped responses
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

    --curl -s https://api.openai.com/v1/models \
    ----header "Authorization: Bearer $OPENAI_API_KEY" \
    --| jq -r '.data[].id'

    fetch_models = function(cb)
        local job = cmd.exec({
            cmd = "curl",
            args = {
                "--no-progress-meter",
                "--header",
                "Authorization: Bearer " .. (os.getenv("OPENAI_API_KEY") or ""),
                "https://api.openai.com/v1/models"
            },
            ---@param err string | nil
            ---@param json_response string | nil
            onread = vim.schedule_wrap(function(err, json_response)
                if err then return cb(err) end
                if not json_response then return end

                ---@type boolean, nil | { data: nil | { id: string }[], error: nil | { message: string } }
                local status_ok, response = pcall(vim.fn.json_decode, json_response)

                -- Failed fetches
                if not status_ok or not response then
                    return cb("error retrieving openai models")
                end

                -- Server error
                if response.error then
                    return cb(response.error.message)
                end

                ---@type string[]
                local models = {}

                for _, model in ipairs(response.data) do
                    -- Many models are offered, only gpt* or chatgpt* models are chat bots, which is what this plugin uses.
                    if model.id:sub(1, 3) == "gpt" or model.id:sub(1, 7) == "chatgpt" then
                        table.insert(models, model.id)
                    end
                end

                return cb(nil, models)
            end)
        })

        return job
    end
}

return Provider
