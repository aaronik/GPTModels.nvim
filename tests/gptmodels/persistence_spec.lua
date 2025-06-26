---@diagnostic disable: undefined-global

local assert = require("luassert")
local stub = require('luassert.stub')
local Store = require("gptmodels.store")

describe("Store | persistence", function()
  local mock_data_path = "/tmp/nvim-test-data"
  local vim_fn_stdpath_stub

  before_each(function()
    Store:clear()
    -- Mock vim.fn.stdpath to return our test data path
    vim_fn_stdpath_stub = stub(vim.fn, 'stdpath')
    vim_fn_stdpath_stub.returns(mock_data_path)
  end)

  after_each(function()
    vim_fn_stdpath_stub:revert()
    -- Clean up test files
    vim.fn.delete(mock_data_path .. "/gptmodels", "rf")
  end)

  describe("load_persisted_state", function()
    it("loads previously saved model selection", function()
      -- Setup: Save a model selection
      Store:set_model("openai", "gpt-4o")
      Store:save_persisted_state()

      -- Clear the store and load persisted state
      Store:clear()
      Store:load_persisted_state()

      local model_info = Store:get_model()
      assert.equal("openai", model_info.provider)
      assert.equal("gpt-4o", model_info.model)
    end)

    it("loads previously saved fetched models", function()
      -- Setup: Save fetched models
      Store:set_models("openai", {"gpt-4o", "gpt-4o-mini"})
      Store:set_models("ollama", {"llama3.1:latest", "deepseek-v2:latest"})
      Store:save_persisted_state()

      -- Clear the store and load persisted state
      Store:clear()
      Store:load_persisted_state()

      assert.same({"gpt-4o", "gpt-4o-mini"}, Store:get_models("openai"))
      assert.same({"llama3.1:latest", "deepseek-v2:latest"}, Store:get_models("ollama"))
    end)

    it("handles missing persistence file gracefully", function()
      -- Ensure no persistence file exists
      vim.fn.delete(mock_data_path .. "/gptmodels", "rf")

      Store:load_persisted_state()

      -- Should not crash and should have empty state
      local model_info = Store:get_model()
      assert.equal("", model_info.provider)
      assert.equal("", model_info.model)
      assert.same({}, Store:get_models("openai"))
      assert.same({}, Store:get_models("ollama"))
    end)

    it("handles corrupted persistence file gracefully", function()
      -- Create corrupted file
      vim.fn.mkdir(mock_data_path .. "/gptmodels", "p")
      local file = io.open(mock_data_path .. "/gptmodels/state.json", "w")
      file:write("invalid json {")
      file:close()

      Store:load_persisted_state()

      -- Should not crash and should have empty state
      local model_info = Store:get_model()
      assert.equal("", model_info.provider)
      assert.equal("", model_info.model)
    end)
  end)

  describe("save_persisted_state", function()
    it("creates data directory if it doesn't exist", function()
      -- Ensure directory doesn't exist
      vim.fn.delete(mock_data_path, "rf")

      Store:set_model("openai", "gpt-4o")
      Store:save_persisted_state()

      -- Verify directory and file were created
      assert.equal(1, vim.fn.isdirectory(mock_data_path .. "/gptmodels"))
      assert.equal(1, vim.fn.filereadable(mock_data_path .. "/gptmodels/state.json"))
    end)
  end)

  describe("auto persistence", function()
    it("automatically saves state when model is changed", function()
      Store:set_model("openai", "gpt-4o")

      -- Should automatically save
      local file = io.open(mock_data_path .. "/gptmodels/state.json", "r")
      assert.is_not_nil(file)
      local content = file:read("*a")
      file:close()

      local data = vim.json.decode(content)
      assert.equal("openai", data.current_provider)
      assert.equal("gpt-4o", data.current_model)
    end)

    it("automatically saves state when models are updated", function()
      Store:set_models("ollama", {"llama3.1:latest", "deepseek-v2:latest"})

      -- Should automatically save
      local file = io.open(mock_data_path .. "/gptmodels/state.json", "r")
      assert.is_not_nil(file)
      local content = file:read("*a")
      file:close()

      local data = vim.json.decode(content)
      assert.same({"llama3.1:latest", "deepseek-v2:latest"}, data.models.ollama)
    end)
  end)
end)
