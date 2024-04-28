---@diagnostic disable: undefined-global

local job = require('plenary.job')
local util = require("gpt.util")
local assert = require("luassert")
local stub = require('luassert.stub')
local ollama = require('gpt.adapters.ollama')

describe("ollama.make_request", function()

    it("passes correct data to curl", function()
        local s = stub(job, "new")

        s.invokes(function(data)
            local args = data.new.calls[1].refs[2]

            -- args is
            -- {
            --   args = { "http://localhost:11434/api/generate", "-d", '{"model": "llama3", "stream": true, "prompt": "What color is an elephant?"}' },
            --   command = "curl",
            --   on_exit = <function 1>,
            --   on_stdout = <function 2>
            -- }

            -- right url in right place
            assert.equal(args.args[1], "http://localhost:11434/api/generate")

            local curl_data_json = args.args[3]
            local curl_data = vim.fn.json_decode(curl_data_json)

            -- model
            assert.equal(curl_data.model, "llama3")

            -- prompt
            assert.equal(curl_data.prompt, "pr0mpT")

            -- return this so job can call :start after :new
            return { start = function() end }
        end)

        ollama.make_request(
            "pr0mpT",
            "llama3",
            function() end,
            function() end
        )

        assert.stub(s).was_called(1)
    end)
end)
