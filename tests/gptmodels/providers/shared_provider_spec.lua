---@diagnostic disable: undefined-global

require('gptmodels.types')
local util = require("gptmodels.util")
local assert = require("luassert")
local stub = require('luassert.stub')
local ollama = require('gptmodels.providers.ollama')
local openai = require('gptmodels.providers.openai')
local cmd = require('gptmodels.cmd')


for _, provider in ipairs({ ollama, openai }) do
  describe('Shared provider specs [' .. provider.name .. ']:', function()
    it('has chat and generate', function()
      assert.not_nil(provider.chat, 'provider is missing method chat')
      assert.not_nil(provider.generate, 'provider is missing method generate')
      assert.not_nil(provider.fetch_models, 'provider is missing method fetch_models')
    end)

    it("generate passes correct data to curl", function()
      local exec_stub = stub(cmd, "exec")

      exec_stub.invokes(function(data)
        ---@type ExecArgs
        local exec_args = data

        local llm_data_json = exec_args.args[3]

        ---@type LlmGenerateArgs | nil
        local llm_data = vim.fn.json_decode(llm_data_json)

        if llm_data == nil then
          error("vim.fn.json_decode returned unexpected nil")
        end

        -- defaults to this
        assert(util.contains_line(exec_args.args, "--data"))
        assert(util.contains_line(exec_args.args, "--no-progress-meter"))
        assert(util.contains_line(exec_args.args, "--no-buffer"))
      end)

      provider.generate({
        llm = {
          prompt = "pr0mpT",
          stream = true,
        },
        on_read = function() end,
      })

      assert.stub(exec_stub).was_called(1)
    end)

    it("generate gracefully handles errors to on_read", function()
      local exec_stub = stub(cmd, "exec")

      exec_stub.invokes(function(data)
        local exec_args = data
        exec_args.onread("error", nil)
      end)

      provider.generate({
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

      assert.stub(exec_stub).was_called(1)
    end)

    it("chat passes correct data to curl", function()
      local messages = { { role = "user", content = "hi" }, { role = "assistant", content = "hi" } }

      local exec_stub = stub(cmd, "exec")

      exec_stub.invokes(function(data)
        ---@type ExecArgs
        local exec_args = data

        local llm_data_json = exec_args.args[3]

        ---@type LlmChatArgs | nil
        local llm_data = vim.fn.json_decode(llm_data_json)

        if llm_data == nil then
          error("vim.fn.json_decode returned unexpected nil")
        end

        assert.same(messages, llm_data.messages)
        assert.equal(llm_data.stream, true)

        assert(util.contains_line(exec_args.args, "--data"))
        assert(util.contains_line(exec_args.args, "--no-progress-meter"))
        assert(util.contains_line(exec_args.args, "--no-buffer"))
      end)

      provider.chat({
        llm = {
          messages = messages,
          stream = true,
        },
        on_read = function() end,
      })

      assert.stub(exec_stub).was_called(1)
    end)

    it("chat gracefully handles errors to on_read", function()
      local exec_stub = stub(cmd, "exec")

      exec_stub.invokes(function(data)
        local exec_args = data
        exec_args.onread("error", nil)
      end)

      provider.chat({
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

      assert.stub(exec_stub).was_called(1)
    end)
  end)
end
