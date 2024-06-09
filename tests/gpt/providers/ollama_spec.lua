---@diagnostic disable: undefined-global

require('gptmodels.types')
local util = require("gptmodels.util")
local assert = require("luassert")
local stub = require('luassert.stub')
local ollama = require('gptmodels.providers.ollama')
local cmd = require('gptmodels.cmd')

describe("ollama.generate", function()
  it("passes correct data to curl", function()
    local s = stub(cmd, "exec")

    s.invokes(function(data)
      ---@type ExecArgs
      local exec_args = data

      -- right url in right place
      assert.equal(exec_args.args[1], "http://localhost:11434/api/generate")

      local llm_data_json = exec_args.args[3]

      ---@type LlmGenerateArgs | nil
      local llm_data = vim.fn.json_decode(llm_data_json)

      if llm_data == nil then
        error("vim.fn.json_decode returned unexpected nil")
      end

      -- defaults to this
      assert.equal(llm_data.model, "llama3")
      assert.equal(llm_data.prompt, "pr0mpT")
      assert.equal(llm_data.stream, true)
      assert(util.contains_line(exec_args.args, "--no-progress-meter"))
    end)

    ollama.generate({
      llm = {
        prompt = "pr0mpT",
        stream = true,
      },
      on_read = function() end,
    })

    assert.stub(s).was_called(1)
  end)

  it("gracefully handles errors to on_read", function()
    local s = stub(cmd, "exec")

    s.invokes(function(data)
      local exec_args = data
      exec_args.onread("error", nil)
    end)

    ollama.generate({
      llm = {
        system = { "system" },
        prompt = "pr0mpT",
        stream = true,
      },
      on_read = function(error, message)
        assert.equal("error", error)
        assert.is_nil(message)
      end,
    })

    assert.stub(s).was_called(1)
  end)

  -- This was giving these huge error messages to the right pane after every response
  it("gracefully handles a clipped final message with no content", function()
    local initial_clipped_json =
    '{"model":"llama3","created_at":"2024-05-14T04:31:47.332514Z","response":"","done":true,"context":[128006,9125],"total_duration":5058894333,"load_duration":1040750958,"prompt_eval_count":1242,"prompt_eval_duration":2508684000,"eval_count":64,"eval_duration":1507712000}'
    local follow_on_one = ",3755,23526"
    local follow_on_two =
    '5,8145,108], "total_duration":3688802667, "load_duration":864584, "prompt_eval_count":1515, "prompt_eval_duration":3633759000, "eval_count":3, "eval_duration":52699000}'


    local exec_stub = stub(cmd, "exec")

    ---@param exec_args ExecArgs
    exec_stub.invokes(function(exec_args)
      exec_args.onread(nil, initial_clipped_json)
      exec_args.onread(nil, follow_on_one)
      exec_args.onread(nil, follow_on_two)
    end)

    local on_read_called = false

    local generate_args = {
      llm = {
        system = { "system" },
        prompt = "pr0mpT",
        stream = true,
      },
      on_read = function() on_read_called = true end,
    }

    ollama.generate(generate_args)
    assert.stub(exec_stub).was_called(1)
    vim.wait(20)
    assert.False(on_read_called)
  end)
end)

describe("ollama.chat", function()
  local messages = { { role = "user", content = "hi" }, { role = "assistant", content = "hi" } }

  it("passes correct data to curl", function()
    local s = stub(cmd, "exec")

    s.invokes(function(data)
      ---@type ExecArgs
      local exec_args = data

      -- right url in right place
      assert.equal(exec_args.args[1], "http://localhost:11434/api/chat")

      local llm_data_json = exec_args.args[3]

      ---@type LlmChatArgs | nil
      local llm_data = vim.fn.json_decode(llm_data_json)

      if llm_data == nil then
        error("vim.fn.json_decode returned unexpected nil")
      end

      assert.equal(llm_data.model, "llama3")
      assert.same(messages, llm_data.messages)
      assert.equal(llm_data.stream, true)
      assert(util.contains_line(exec_args.args, "--no-progress-meter"))
    end)

    ollama.chat({
      llm = {
        messages = messages,
        stream = true,
      },
      on_read = function() end,
    })

    assert.stub(s).was_called(1)
  end)

  it("gracefully handles errors to on_read", function()
    local s = stub(cmd, "exec")

    s.invokes(function(data)
      local exec_args = data
      exec_args.onread("error", nil)
    end)

    ollama.chat({
      llm = {
        messages = { role = "system", content = "yo" },
        prompt = "pr0mpT",
        stream = true,
      },
      on_read = function(error, message)
        assert.equal("error", error)
        assert.is_nil(message)
      end,
    })

    assert.stub(s).was_called(1)
  end)

  -- This was giving these huge error messages to the right pane after every response
  it("gracefully handles a weird final message with no content", function()
    local initial_clipped_json =
    '{"model":"llama3","created_at":"2024-05-14T04:31:47.332514Z","response":"","done":true,"context":[128006,9125],"total_duration":5058894333,"load_duration":1040750958,"prompt_eval_count":1242,"prompt_eval_duration":2508684000,"eval_count":64,"eval_duration":1507712000}'
    local follow_on_one = ",3755,23526"
    local follow_on_two =
    '5,8145,108], "total_duration":3688802667, "load_duration":864584, "prompt_eval_count":1515, "prompt_eval_duration":3633759000, "eval_count":3, "eval_duration":52699000}'

    local exec_stub = stub(cmd, "exec")

    ---@param exec_args ExecArgs
    exec_stub.invokes(function(exec_args)
      exec_args.onread(nil, initial_clipped_json)
      exec_args.onread(nil, follow_on_one)
      exec_args.onread(nil, follow_on_two)
    end)

    ---@type MakeChatRequestArgs
    local chat_args = {
      llm = {
        system = "system",
        stream = true,
      },
      on_read = function() end,
    }

    local on_read_stub = stub(chat_args, "on_read")
    ollama.chat(chat_args)
    assert.stub(exec_stub).was_called(1)
    vim.wait(20)
    assert.stub(on_read_stub).was_called(0)
  end)
end)

describe("ollama.fetch_models", function()
  it("returns list of available ollama models", function()
    local exec_stub = stub(cmd, "exec")
    local finished = false
    ---@type string[] | nil
    local models = {}

    ollama.fetch_models(function(_, ms)
      models = ms
      finished = true
    end)

    ---@type ExecArgs
    local exec_args = exec_stub.calls[1].refs[1]

    local response = [[
    {
      "models": [
        { "name": "deepseek-coder:33b" },
        { "name": "dolphin-mistral:latest" },
        { "name": "dolphincoder:15b" },
        { "name": "gemma:latest" },
        { "name": "llama2-uncensored:latest" },
        { "name": "llama3:latest" },
        { "name": "mistral:latest" }
      ]
    }
    ]]

    exec_args.onread(nil, response)

    vim.wait(20, function() return finished end)

    assert.is_nil(err)
    assert.same(
      { "deepseek-coder:33b", "dolphin-mistral:latest", "dolphincoder:15b", "gemma:latest", "llama2-uncensored:latest",
        "llama3:latest", "mistral:latest" }, models)
  end)
end)
