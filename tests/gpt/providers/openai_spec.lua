---@diagnostic disable: undefined-global

require('gpt.types')
local util = require("gpt.util")
local assert = require("luassert")
local stub = require('luassert.stub')
local openai = require('gpt.providers.openai')
local cmd = require('gpt.cmd')

describe("openai.generate", function()
  it("passes correct data to curl", function()
    local s = stub(cmd, "exec")

    s.invokes(function(data)
      ---@type ExecArgs
      local exec_args = data

      -- right url in right place
      assert.equal(exec_args.args[1], "https://api.openai.com/v1/chat/completions")

      local llm_data_json = exec_args.args[3]

      ---@type LlmGenerateArgs | nil
      local llm_data = vim.fn.json_decode(llm_data_json)

      if llm_data == nil then
        error("vim.fn.json_decode returned unexpected nil")
      end

      assert.equal("gpt-4-turbo", llm_data.model)
      assert.equal(nil, llm_data.prompt)
      ---@diagnostic disable-next-line: undefined-field
      assert.same({ { role = "user", content = "pr0mpT" }, { role = "system", content = "system" } }, llm_data.messages)
      assert.equal(true, llm_data.stream)

      -- Ensure OPENAI_API_KEY is passed in correctly
      assert.equal("Authorization: Bearer " .. os.getenv("OPENAI_API_KEY"), exec_args.args[5])

      -- This is how it comes in from openai for whatever reason. Note role needs to be injected most of the time
      exec_args.onread(nil, 'data: { "choices": [{ "delta": { "content": "hi from llm" } } ] }\r\n')

      -- required for the assert in the on_read to be picked up for some reason
      vim.wait(10)
    end)

    openai.generate({
      llm = {
        system = { "system" },
        prompt = "pr0mpT",
        stream = true,
      },
      on_read = function(_, message)
        assert.same("hi from llm", message)
      end,
    })

    assert.stub(s).was_called(1)
  end)
end)

describe("openai.chat", function()
  local messages = { { role = "user", content = "hi" }, { role = "assistant", content = "hi" } }

  it("passes correct data to curl", function()
    local cmd_stub = stub(cmd, "exec")

    cmd_stub.invokes(function(data)
      ---@type ExecArgs
      local exec_args = data

      -- right url in right place
      assert.equal(exec_args.args[1], "https://api.openai.com/v1/chat/completions")

      local llm_data_json = exec_args.args[3]

      ---@type LlmChatArgs | nil
      local llm_data = vim.fn.json_decode(llm_data_json)

      if llm_data == nil then
        error("vim.fn.json_decode returned unexpected nil")
      end

      assert.equal("gpt-4-turbo", llm_data.model)
      assert.same(llm_data.messages, messages)
      assert.equal(true, llm_data.stream)

      -- Ensure OPENAI_API_KEY is passed in correctly
      assert.equal("Authorization: Bearer " .. os.getenv("OPENAI_API_KEY"), exec_args.args[5])

      local sample_llm_response =
      'data: {"id":"chatcmpl-9NlDMQabkgi97t6OQTDXQKwGt7mx4","object":"chat.completion.chunk","created":1715450064,"model":"gpt-4-turbo-2024-04-09","system_fingerprint":"fp_294de9593d","choices":[{"index":0,"delta":{"content":"both"},"logprobs":null,"finish_reason":null}]}'

      sample_llm_response = sample_llm_response ..
          '\n\ndata: {"id":"chatcmpl-9NlDMQabkgi97t6OQTDXQKwGt7mx4","object":"chat.completion.chunk","created":1715450064,"model":"gpt-4-turbo-2024-04-09","system_fingerprint":"fp_294de9593d","choices":[{"index":0,"delta":{"content":" halves"},"logprobs":null,"finish_reason":null}]}\n\n'

      -- This is how it comes in from openai for whatever reason. Note role needs to be injected most of the time
      exec_args.onread(nil, sample_llm_response)

      -- required for the assert in the on_read to be picked up for some reason
      vim.wait(10)
    end)

    local count = 0
    local finished = false

    openai.chat({
      llm = {
        messages = messages,
        stream = true,
      },
      on_read = function(_, message)
        if count == 0 then
          assert.same({ content = "both", role = "assistant" }, message)
          count = count + 1
        else
          assert.same({ content = " halves", role = "assistant" }, message)
          finished = true
        end
      end,
    })

    vim.wait(50, function()
      return finished
    end)

    -- Assert that both halves of the response got put into on_read
    assert.True(finished)

    assert.stub(cmd_stub).was_called(1)
  end)
end)
