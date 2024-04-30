---@diagnostic disable: undefined-global

require('gpt.types')
local job = require('plenary.job')
local util = require("gpt.util")
local assert = require("luassert")
local stub = require('luassert.stub')
local ollama = require('gpt.adapters.ollama')

describe("ollama.make_request", function()
  it("passes correct data to curl", function()
    local s = stub(job, "new")

    ---job:new(args)
    s.invokes(function(data)
      ---args = { "http://localhost:11434/api/generate", "-d", '{"model": "llama3", "stream": true, "prompt": "string", "etc" }' },
      ---@type { args: string[], command: "curl", on_exit: function, on_stdout: function }
      local args = data.new.calls[1].refs[2]

      -- right url in right place
      assert.equal(args.args[1], "http://localhost:11434/api/generate")

      local curl_data_json = args.args[3]

      ---@type LlmArgs | nil
      local curl_data = vim.fn.json_decode(curl_data_json)

      if curl_data == nil then
        error("vim.fn.json_decode returned unexpected nil")
      end

      assert.equal(curl_data.model, "llama3")
      assert.equal(curl_data.prompt, "pr0mpT")
      assert.same(curl_data.messages, {})
      assert.equal(curl_data.stream, true)

      -- return this so job can call :start after :new
      return { start = function() end }
    end)

    ollama.chat({
      llm = {
        prompt = "pr0mpT",
        model = "llama3",
        messages = {},
        stream = true,
      },
      on_response = function() end,
      kind = "generate" -- TODO Chat
    })

    assert.stub(s).was_called(1)
  end)
end)
