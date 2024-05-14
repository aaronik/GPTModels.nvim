local util = require('gpt.util')
local cmd = require('gpt.cmd')
require('gpt.types')

local M = {}

-- Both endpoints will use the same onread, since it's actually the same endpoint for openai
---@param json string
---@return string | nil, LlmMessage[] | nil
local parse_llm_response = function(json)

    -- replace \r\n with just \n
    json = string.gsub(json, "\r\n", "\n")

    -- Break on newlines, remove empty lines
    local json_lines = vim.split(json, "\n")
    json_lines = vim.tbl_filter(function(line) return line ~= "" end, json_lines)

    -- Then, for some reason all their lines start with data: . Just the string, not json. Weird.
    for i, line in ipairs(json_lines) do
        json_lines[i] = line:sub(7)
    end

    ---@type LlmMessage[]
    local messages = {}

    for _, line in ipairs(json_lines) do
        if line == '[DONE]' or line == "" then
            break
        end

        -- TODO This is not how to handle errors.
        -- Just return the error.
        ---@type boolean, { choices: { delta: LlmMessage }[] } | nil
        local status_ok, data = pcall(vim.fn.json_decode, line)
        if not status_ok or not data or not data.choices or not data.choices[1].delta then
            return "JSON decode or schema error for LLM response!  " .. line .. ":\n" .. vim.inspect(data) .. "\n\n"
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

-- curl -X POST -H "Authorization: Bearer $OPENAI_API_KEY" -H "Content-Type: application/json" -d '{
--   "model": "gpt-4-turbo",
--   "messages": [{ "role": "user", "content": "Translate this text into French: Hello, world!" }]
-- }' https://api.openai.com/v1/chat/completions

---@param args MakeGenerateRequestArgs
---@return Job
M.generate = function(args)
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
        "--silent",
        "--no-buffer",
    }

    local job = cmd.exec({
        cmd = "curl",
        args = curl_args,
        onread = vim.schedule_wrap(function(err, response)
            if err then return args.on_read(err, nil) end
            if not response then return end

            local parse_error, messages = parse_llm_response(response)

            if parse_error then
                return args.on_read(parse_error)
            end

            if not messages then
                return
            end

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
end

---@param args MakeChatRequestArgs
---@return Job
M.chat = function(args)
    local url = "https://api.openai.com/v1/chat/completions"

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
        "--silent",
    }

    local job = cmd.exec({
        cmd = "curl",
        args = curl_args,
        onread = vim.schedule_wrap(function(err, json)
            if err then return args.on_read(err, nil) end
            if not json then return end

            local parse_error, messages = parse_llm_response(json)

            if parse_error then
                return args.on_read(parse_error)
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
end

return M
