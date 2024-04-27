---@diagnostic disable: undefined-global

-- curl http://localhost:11434/api/generate -d '{ "model": "llama2-uncensored", "prompt": "What is water made of?" }'

local job = require('plenary.job')
local util = require("gpt.util")
local assert = require("luassert")
local stub = require('luassert.stub')

local make_request = function(prompt, model, on_response, on_end)
    local args = {
        "http://localhost:11434/api/generate",
        "-d",
        vim.fn.json_encode({ model = model, prompt = prompt, stream = true })
    }

    job
        :new({
            command = "curl",
            args = args,
            on_stdout = vim.schedule_wrap(function(_, data)
                if data then
                    local json = vim.fn.json_decode(data)
                    on_response(json.response)
                end
            end),
            on_exit = vim.schedule_wrap(function()
                on_end()
            end)
        })
        :start()
end

describe("ollama generate", function()
    it("calls to localhost", function()
        local s = stub(job, "new")

        s.invokes(function (data)
            local args = data.new.calls[1].refs[2]
            P(args)

            -- return this so job can call :start after :new
            return { start = function() end}
        end)

        make_request(
            "What color is an elephant?",
            "llama2-uncensored",
            print,
            function() end
        )

        assert.stub(s).was_called(1)
    end)
end)
