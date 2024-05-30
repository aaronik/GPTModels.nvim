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
      local args = data

      -- right url in right place
      assert.equal(args.args[1], "http://localhost:11434/api/generate")

      local llm_data_json = args.args[3]

      ---@type LlmGenerateArgs | nil
      local llm_data = vim.fn.json_decode(llm_data_json)

      if llm_data == nil then
        error("vim.fn.json_decode returned unexpected nil")
      end

      -- defaults to this
      assert.equal(llm_data.model, "llama3")
      assert.equal(llm_data.prompt, "pr0mpT")
      assert.equal(llm_data.stream, true)
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
  it("gracefully handles a weird final message with no content", function()
    local weird_json =
    '{"model":"llama3","created_at":"2024-05-14T04:31:47.332514Z","response":"","done":true,"context":[128006,9125],"total_duration":5058894333,"load_duration":1040750958,"prompt_eval_count":1242,"prompt_eval_duration":2508684000,"eval_count":64,"eval_duration":1507712000}'

    local exec_stub = stub(cmd, "exec")

    exec_stub.invokes(function(exec_args)
      exec_args.onread(nil, weird_json)
    end)

    local generate_args = {
      llm = {
        system = { "system" },
        prompt = "pr0mpT",
        stream = true,
      },
      on_read = function() end,
    }

    local on_read_stub = stub(generate_args, "on_read")

    ollama.generate(generate_args)

    assert.stub(exec_stub).was_called(1)

    vim.wait(20)

    assert.stub(on_read_stub).was_called(0)
  end)
end)

describe("ollama.chat", function()
  local messages = { { role = "user", content = "hi" }, { role = "assistant", content = "hi" } }

  it("passes correct data to curl", function()
    local s = stub(cmd, "exec")

    s.invokes(function(data)
      ---@type ExecArgs
      local args = data

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
    local weird_json =
    '{"model":"llama3","created_at":"2024-05-14T04:31:47.332514Z","response":"","done":true,"context":[128006,9125],"total_duration":5058894333,"load_duration":1040750958,"prompt_eval_count":1242,"prompt_eval_duration":2508684000,"eval_count":64,"eval_duration":1507712000}'

    local exec_stub = stub(cmd, "exec")

    exec_stub.invokes(function(exec_args)
      exec_args.onread(nil, weird_json)
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

    ollama.fetch_models(function(err, ms)
      models = ms
      finished = true
    end)

    ---@type ExecArgs
    local exec_args = exec_stub.calls[1].refs[1]

    assert.equal(exec_args.cmd, "ollama")
    assert.same(exec_args.args, { "list" })

    local response = [[
      NAME                    	ID          	SIZE  	MODIFIED
      deepseek-coder:33b      	acec7c0b0fd9	18 GB 	17 seconds ago
      dolphin-mistral:latest  	5dc8c5a2be65	4.1 GB	7 weeks ago
      dolphincoder:15b        	1102380927c2	9.1 GB	12 days ago
      gemma:latest            	a72c7f4d0a15	5.0 GB	7 weeks ago
      llama2-uncensored:latest	44040b922233	3.8 GB	7 weeks ago
      llama3:latest           	a6990ed6be41	4.7 GB	4 weeks ago
      mistral:latest          	61e88e884507	4.1 GB	7 weeks ago
    ]]

    exec_args.onread(nil, response)

    vim.wait(20, function() return finished end)

    assert.is_nil(err)
    assert.same(
      { "deepseek-coder:33b", "dolphin-mistral:latest", "dolphincoder:15b", "gemma:latest", "llama2-uncensored:latest",
        "llama3:latest", "mistral:latest" }, models)
  end)
end)
