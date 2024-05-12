---@diagnostic disable: undefined-global

local util = require("gpt.util")
local assert = require("luassert")
local stub = require('luassert.stub')
local llm = require('gpt.llm')
local Store = require('gpt.store')
local ollama = require('gpt.providers.ollama')
local openai = require('gpt.providers.openai')

describe("gpt.llm", function()
  describe("calling the provider stored in the Store", function()
    local old_provider
    local old_model
    local ollama_chat_stub
    local ollama_generate_stub
    local openai_chat_stub
    local openai_generate_stub
    local snapshot

    before_each(function()
      snapshot = assert:snapshot()
      old_provider = Store.llm_provider
      old_model = Store.llm_model

      ollama_chat_stub = stub(ollama, 'chat')
      ollama_generate_stub = stub(ollama, 'generate')
      openai_chat_stub = stub(openai, 'chat')
      openai_generate_stub = stub(openai, 'generate')
    end)

    after_each(function()
      Store.llm_provider = old_provider
      Store.llm_model = old_model
      snapshot:revert()
    end)

    it("for ollama/chat", function()
      Store.llm_provider = "ollama"
      Store.llm_model = "mawdle"

      llm.chat({
        llm = {
          stream = true,
        },
        on_read = function() end
      })

      assert.stub(ollama_chat_stub).was_called(1)

      ---@type MakeChatRequestArgs
      local args = ollama_chat_stub.calls[1].refs[1]
      assert.equal("mawdle", args.llm.model)
    end)

    it("for ollama/generate", function()
      Store.llm_provider = "ollama"
      Store.llm_model = "mawdle"

      llm.generate({
        llm = {
          prompt = "generate meh",
          stream = true,
        },
        on_read = function() end
      })

      assert.stub(ollama_generate_stub).was_called(1)

      ---@type MakeGenerateRequestArgs
      local args = ollama_generate_stub.calls[1].refs[1]
      assert.equal("mawdle", args.llm.model)
    end)

    it("for openai/chat", function()
      Store.llm_provider = "openai"
      Store.llm_model = "mawdle"

      llm.chat({
        llm = {
          stream = true,
        },
        on_read = function() end
      })

      assert.stub(openai_chat_stub).was_called(1)

      ---@type MakeChatRequestArgs
      local args = openai_chat_stub.calls[1].refs[1]
      assert.equal("mawdle", args.llm.model)
    end)

    it("for openai/generate", function()
      Store.llm_provider = "openai"
      Store.llm_model = "mawdle"

      llm.generate({
        llm = {
          prompt = "generate meh",
          stream = true,
        },
        on_read = function() end
      })

      assert.stub(openai_generate_stub).was_called(1)

      ---@type MakeGenerateRequestArgs
      local args = openai_generate_stub.calls[1].refs[1]
      assert.equal("mawdle", args.llm.model)
    end)

  end)
end)
