---@diagnostic disable: undefined-global

require('gptmodels.types')
local util = require("gptmodels.util")
local assert = require("luassert")
local stub = require('luassert.stub')
local openai = require('gptmodels.providers.openai')
local cmd = require('gptmodels.cmd')

describe("openai.generate", function()
  it("passes correct data to curl", function()
    local exec_stub = stub(cmd, "exec")

    exec_stub.invokes(function(data)
      ---@type ExecArgs
      local exec_args = data

      -- right url in right place
      assert.equal(exec_args.args[1], "https://api.openai.com/v1/chat/completions")

      local llm_data_json = exec_args.args[3]

      assert(util.contains_line(exec_args.args, "--no-progress-meter"))

      ---@type LlmGenerateArgs | nil
      local llm_data = vim.fn.json_decode(llm_data_json)

      if llm_data == nil then
        error("vim.fn.json_decode returned unexpected nil")
      end

      assert.equal(nil, llm_data.prompt)
      ---@diagnostic disable-next-line: undefined-field
      assert.same({ { role = "user", content = "pr0mpT" }, { role = "system", content = "system" } }, llm_data.messages)
      assert.equal(true, llm_data.stream)

      -- Ensure OPENAI_API_KEY is passed in correctly
      assert.equal("Authorization: Bearer " .. (os.getenv("OPENAI_API_KEY") or ""), exec_args.args[5])

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

    assert.stub(exec_stub).was_called(1)
  end)

  it("handles clipped responses", function()
    local exec_stub = stub(cmd, "exec")

    -- Two responses, which contain three messages, one of which is split (clipped) across the two responses
    -- All messages are just "hello"
    local response_1 =
        'data: {"id":"chatcmpl-9v8g31Z2PfncKDYcmlIwX9HNkmbRa","object":"chat.completion.chunk","created":1723405079,'
        .. '"model":"gpt-4o-2024-05-13","system_fingerprint":"fp_3aa7262c27","choices":[{"index":0,"delta":'
        .. '{"content":"hello"},"logprobs":null,"finish_reason":null}]}\r\ndata: {"id":"chatcmpl-9v8g31Z2PfncKDYcmlIw'
    local response_2 =
        'X9HNkmbRa","object":"chat.completion.chunk","created":1723405079,"model":"gpt-4o-2024-05-13",'
        .. '"system_fingerprint":"fp_3aa7262c27","choices":[{"index":0,"delta":{"content":"hello"},"logprobs":null,'
        .. '"finish_reason":null}]}\r\ndata: {"id":"chatcmpl-9v8g31Z2PfncKDYcmlIwX9HNkmbRa","object":"chat.completion'
        .. '.chunk","created":1723405079,"model":"gpt-4o-2024-05-13","system_fingerprint":"fp_3aa7262c27","choices":'
        .. '[{"index":0,"delta":{"content":"hello"},"logprobs":null,"finish_reason":null}]}'

    exec_stub.invokes(function(data)
      local exec_args = data
      exec_args.onread(nil, response_1)
      exec_args.onread(nil, response_2)
    end)

    local on_read_call_count = 0

    openai.generate({
      llm = {
        system = { "system" },
        prompt = "pr0mpT",
        stream = true,
      },
      on_read = function(error, message)
        assert.is_nil(error)
        assert.equal("hello", message)
        on_read_call_count = on_read_call_count + 1
      end,
    })

    vim.wait(20)
    assert.stub(exec_stub).was_called(1)
    assert.equal(on_read_call_count, 3)
  end)
end)

describe("openai.chat", function()
  local messages = { { role = "user", content = "hi" }, { role = "assistant", content = "hi" } }

  it("passes correct data to curl", function()
    local cmd_stub = stub(cmd, "exec")

    -- intercept curl call
    cmd_stub.invokes(function(data)
      ---@type ExecArgs
      local exec_args = data

      -- right url
      assert(vim.list_contains(exec_args.args, "https://api.openai.com/v1/chat/completions"))
      assert(vim.list_contains(exec_args.args, "--no-progress-meter"))

      local llm_data_json = exec_args.args[3]

      ---@type LlmChatArgs | nil
      local llm_data = vim.fn.json_decode(llm_data_json)

      if llm_data == nil then
        error("vim.fn.json_decode returned unexpected nil")
      end

      assert.same(llm_data.messages, messages)
      assert.equal(true, llm_data.stream)

      -- Ensure OPENAI_API_KEY is passed in correctly
      assert(vim.list_contains(exec_args.args, "Authorization: Bearer " .. (os.getenv("OPENAI_API_KEY") or "")))

      local sample_llm_response =
          'data: {"id":"chatcmpl-9NlDMQabkgi97t6OQTDXQKwGt7mx4","object":"chat.completion.chunk","created":1715450064,'
          .. '"model":"gpt-4-turbo-2024-04-09","system_fingerprint":"fp_294de9593d","choices":[{"index":0,"delta":'
          .. '{"content":"both"},"logprobs":null,"finish_reason":null}]}'

      sample_llm_response = sample_llm_response ..
          '\n\ndata: {"id":"chatcmpl-9NlDMQabkgi97t6OQTDXQKwGt7mx4","object":"chat.completion.chunk",'
          .. '"created":1715450064,"model":"gpt-4-turbo-2024-04-09","system_fingerprint":"fp_294de9593d",'
          .. '"choices":[{"index":0,"delta":{"content":" halves"},"logprobs":null,"finish_reason":null}]}\n\n'

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

  it("handles clipped responses", function()
    local exec_stub = stub(cmd, "exec")

    -- Two responses, which contain three messages, one of which is split (clipped) across the two responses
    -- All messages are just "hello"
    local response_1 =
    'data: {"id":"chatcmpl-9v8g31Z2PfncKDYcmlIwX9HNkmbRa","object":"chat.completion.chunk","created":1723405079,'
      .. '"model":"gpt-4o-2024-05-13","system_fingerprint":"fp_3aa7262c27","choices":[{"index":0,"delta":'
      .. '{"content":"hello"},"logprobs":null,"finish_reason":null}]}\r\ndata: {"id":"chatcmpl-9v8g31Z2PfncKDYcmlIw'
    local response_2 =
    'X9HNkmbRa","object":"chat.completion.chunk","created":1723405079,"model":"gpt-4o-2024-05-13",'
      .. '"system_fingerprint":"fp_3aa7262c27","choices":[{"index":0,"delta":{"content":"hello"},'
      .. '"logprobs":null,"finish_reason":null}]}\r\ndata: {"id":"chatcmpl-9v8g31Z2PfncKDYcmlIwX9HNkmbRa"'
      .. ',"object":"chat.completion.chunk","created":1723405079,"model":"gpt-4o-2024-05-13","system_fingerprint":'
      .. '"fp_3aa7262c27","choices":[{"index":0,"delta":{"content":"hello"},"logprobs":null,"finish_reason":null}]}'

    exec_stub.invokes(function(data)
      local exec_args = data
      exec_args.onread(nil, response_1)
      exec_args.onread(nil, response_2)
    end)

    local on_read_call_count = 0

    openai.chat({
      llm = {
        prompt = "pr0mpT",
        stream = true,
      },
      on_read = function(error, message)
        assert.is_nil(error)
        assert.equal("hello", message and message.content)
        on_read_call_count = on_read_call_count + 1
      end,
    })

    vim.wait(20)
    assert.stub(exec_stub).was_called(1)
    assert.equal(3, on_read_call_count)
  end)
end)

describe("openai.fetch_models", function()
  it("returns list of available openai models", function()
    local exec_stub = stub(cmd, "exec")

    ---@type string[] | nil
    local models = {}
    local finished = false
    local error = nil

    openai.fetch_models(function(err, ms)
      error = err
      models = ms
      finished = true
    end)

    ---@type ExecArgs
    local exec_args = exec_stub.calls[1].refs[1]

    local openai_response = [[
    {
      "data": [
        { "id": "gpt-4o" },
        { "id": "gpt-4o-mini" },
        { "id": "gpt-3.5-turbo-1106" },
        { "id": "chatgpt-4o-latest" },
        { "id": "babbage-002" },
        { "id": "whisper-1" },
        { "id": "davinci-002" }
      ]
    }
    ]]

    exec_args.onread(nil, openai_response)
    vim.wait(20, function() return finished end)

    assert.is_nil(error)
    assert.same(
      { "gpt-4o", "gpt-4o-mini", "gpt-3.5-turbo-1106", "chatgpt-4o-latest" },
      models
    )
  end)

  it("correctly handles openai errors", function()
    local exec_stub = stub(cmd, "exec")
    local error = nil
    local finished = false
    openai.fetch_models(function(err)
      error = err
      finished = true
    end)

    ---@type ExecArgs
    local exec_args = exec_stub.calls[1].refs[1]
    local openai_response = '{"error": {"message": "Error message"}}'
    exec_args.onread(nil, openai_response)
    vim.wait(20, function() return finished end)
    assert.equal(error, "Error message")
  end)

  it("doesn't explode when no OPENAI_API_KEY is set", function()
    stub(os, "getenv").invokes(function(env_var)
      if env_var == "OPENAI_API_KEY" then
        return nil
      else
        return os.getenv(env_var)
      end
    end)

    openai.fetch_models(function()
    end)
  end)
end)
