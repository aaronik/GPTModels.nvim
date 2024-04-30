---@diagnostic disable: undefined-global

require('gpt.types')
local job = require('plenary.job')
local util = require("gpt.util")
local assert = require("luassert")
local stub = require('luassert.stub')
local ollama = require('gpt.adapters.ollama')

describe("ollama.generate", function()
  it("passes correct data to curl", function()
    local s = stub(job, "new")

    ---job:new(args)
    s.invokes(function(data)
      ---args = { "http://localhost:11434/api/generate", "-d", '{"model": "llama3", "stream": true, "prompt": "string", "etc" }' },
      ---@type { args: string[], command: "curl", on_exit: function, on_stdout: function }
      local args = data.new.calls[1].refs[2]

      -- right url in right place
      assert.equal(args.args[1], "http://localhost:11434/api/generate")

      local llm_data_json = args.args[3]

      ---@type LlmGenerateArgs | nil
      local llm_data = vim.fn.json_decode(llm_data_json)

      if llm_data == nil then
        error("vim.fn.json_decode returned unexpected nil")
      end

      assert.equal(llm_data.model, "llama3")
      assert.equal(llm_data.prompt, "pr0mpT")
      assert.equal(llm_data.stream, true)

      -- return this so job can call :start after :new
      return { start = function() end }
    end)

    ollama.generate({
      llm = {
        prompt = "pr0mpT",
        model = "llama3",
        stream = true,
      },
      on_response = function() end,
    })

    assert.stub(s).was_called(1)
  end)
end)

describe("ollama.chat", function()
  local messages = { { role = "user", content = "hi" }, { role = "assistant", content = "hi" } }

  it("passes correct data to curl", function()
    local s = stub(job, "new")

    ---job:new(args)
    s.invokes(function(data)
      ---args = { "http://localhost:11434/api/generate", "-d", '{"model": "llama3", "stream": true, "prompt": "string", "etc" }' },
      ---@type { args: string[], command: "curl", on_exit: function, on_stdout: function }
      local args = data.new.calls[1].refs[2]

      -- right url in right place
      assert.equal(args.args[1], "http://localhost:11434/api/chat")

      local llm_data_json = args.args[3]

      ---@type LlmChatArgs | nil
      local llm_data = vim.fn.json_decode(llm_data_json)

      if llm_data == nil then
        error("vim.fn.json_decode returned unexpected nil")
      end

      assert.equal(llm_data.model, "llama3")
      assert.same(messages, llm_data.messages)
      assert.equal(llm_data.stream, true)

      -- return this so job can call :start after :new
      return { start = function() end }
    end)

    ollama.chat({
      llm = {
        model = "llama3",
        messages = messages,
        stream = true,
      },
      on_response = function() end,
    })

    assert.stub(s).was_called(1)
  end)
end)
