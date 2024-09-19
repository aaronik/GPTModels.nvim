---@diagnostic disable: undefined-global

require('gptmodels.types')
local util = require("gptmodels.util")
local assert = require("luassert")
local stub = require('luassert.stub')
local ollama = require('gptmodels.providers.ollama')
local cmd = require('gptmodels.cmd')

describe("ollama.generate", function()
  it("passes correct data to curl", function()
    local exec_stub = stub(cmd, "exec")

    exec_stub.invokes(function(data)
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

    assert.stub(exec_stub).was_called(1)
  end)

  it('combines clipped responses', function()
    local initial_clipped_json = '{"model":"whatever","created_at":"2024-05-14T04:31:47.332514Z","respo'
    local follow_on_one = 'nse":"hiya","done":false,"context":[128006,9125],"total_duration":5058894333,"load_d'
    local follow_on_two =
    'uration":1040750958,"prompt_eval_count":1242,"prompt_eval_duration":2508684000,"eval_count":64,"eval_duration":1507712000}'

    local exec_stub = stub(cmd, "exec")

    ---@param exec_args ExecArgs
    exec_stub.invokes(function(exec_args)
      exec_args.onread(nil, initial_clipped_json)
      exec_args.onread(nil, follow_on_one)
      exec_args.onread(nil, follow_on_two)
    end)

    ---@type string | nil
    local on_read_args = ""

    ---@type MakeGenerateRequestArgs
    local generate_args = {
      llm = {
        system = { "system" },
        prompt = "pr0mpT",
        stream = true,
      },
      on_read = function(_, args)
        on_read_args = args
      end,
    }

    ollama.generate(generate_args)
    assert.stub(exec_stub).was_called(1)
    vim.wait(20)
    assert.equal("hiya", on_read_args)
  end)
end)

describe("ollama.chat", function()
  local messages = { { role = "user", content = "hi" }, { role = "assistant", content = "hi" } }

  it("passes correct data to curl", function()
    local exec_stub = stub(cmd, "exec")

    exec_stub.invokes(function(data)
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

    assert.stub(exec_stub).was_called(1)
  end)

  it('combines clipped responses', function()
    local initial_clipped_json = '{"model":"llama3","created_at":"2024-05-14T04:31:47.332514Z","mess'
    local follow_on_one =
    'age":{"content": "hiya", "role": "assistant"},"done":false,"context":[128006,9125],"total_duration":5058894333,"load_d'
    local follow_on_two =
    'uration":1040750958,"prompt_eval_count":1242,"prompt_eval_duration":2508684000,"eval_count":64,"eval_duration":1507712000}'

    local exec_stub = stub(cmd, "exec")

    ---@param exec_args ExecArgs
    exec_stub.invokes(function(exec_args)
      exec_args.onread(nil, initial_clipped_json)
      exec_args.onread(nil, follow_on_one)
      exec_args.onread(nil, follow_on_two)
    end)

    ---@type string | nil
    local on_read_args = ""

    ---@type MakeChatRequestArgs
    local chat_args = {
      llm = {
        system = "system",
        stream = true,
      },
      on_read = function(_, args)
        on_read_args = args and args.content
      end,
    }

    ollama.chat(chat_args)
    assert.stub(exec_stub).was_called(1)
    vim.wait(20)
    assert.equal('hiya', on_read_args)
  end)
end)

describe("ollama.fetch_models", function()
  it("returns list of available ollama models", function()
    local exec_stub = stub(cmd, "exec")
    local finished = false
    ---@type string[] | nil
    local models = {}
    local error = nil

    ollama.fetch_models(function(err, ms)
      error = err
      models = ms
      finished = true
    end)

    ---@type ExecArgs
    local exec_args = exec_stub.calls[1].refs[1]

    local ollama_response = [[
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

    exec_args.onread(nil, ollama_response)

    vim.wait(20, function() return finished end)

    assert.is_nil(error)
    assert.same(
      { "deepseek-coder:33b", "dolphin-mistral:latest", "dolphincoder:15b", "gemma:latest", "llama2-uncensored:latest",
        "llama3:latest", "mistral:latest" }, models)
  end)
end)
