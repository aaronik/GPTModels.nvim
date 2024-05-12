---@diagnostic disable: undefined-global

require('gpt.types')
local util = require("gpt.util")
local assert = require("luassert")
local stub = require('luassert.stub')
local ollama = require('gpt.providers.ollama')
local cmd = require('gpt.cmd')

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
end)
