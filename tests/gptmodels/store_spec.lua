---@diagnostic disable: undefined-global

local util   = require("gptmodels.util")
local Store  = require("gptmodels.store")
local assert = require("luassert")

describe("Store | setting / getting", function()
  before_each(function()
    Store:clear()
  end)

  it("sets and gets window content", function()
    Store.code.right:append("right")
    Store.code.right:append("right")

    Store.code.left:append("left")
    Store.code.left:append("left")

    Store.code.input:append("input")
    Store.code.input:append("input")

    Store.chat.input:append("input")
    Store.chat.input:append("input")

    Store.chat.chat:append({ role = "assistant", content = "chat" })
    Store.chat.chat:append({ role = "assistant", content = "chat" })

    assert.equal("rightright", Store.code.right:read())
    assert.equal("leftleft", Store.code.left:read())
    assert.equal("inputinput", Store.code.input:read())

    assert.equal("inputinput", Store.chat.input:read())
    assert.same({ { role = "assistant", content = "chatchat" } }, Store.chat.chat:read())
  end)

  it("sets and gets included files", function()
    Store.code:append_file("lua/gpt/windows/code.lua")
    Store.code:append_file("lua/gpt/windows/chat.lua")

    Store.chat:append_file("lua/gpt/windows/code.lua")
    Store.chat:append_file("lua/gpt/windows/chat.lua")

    assert.same({ "lua/gpt/windows/code.lua", "lua/gpt/windows/chat.lua" }, Store.code:get_filenames())
    assert.same({ "lua/gpt/windows/code.lua", "lua/gpt/windows/chat.lua" }, Store.chat:get_filenames())
  end)
end)

describe("Store | messages", function()
  before_each(function()
    Store.chat:clear()
  end)

  it("starts with empty table", function()
    Store.chat.chat:append({ role = "assistant", content = "hello" })
    Store.chat:clear()
    assert.same({}, Store.chat.chat:read())
  end)

  it("clears messages", function()
    Store.chat.chat:append({ role = "assistant", content = "hello" })
    Store.chat:clear()
    assert.same({}, Store.chat.chat:read())
  end)

  it("Adds, joins, and gets messages", function()
    Store.chat.chat:append({ role = "user", content = "hello" })
    assert.same({ { role = "user", content = "hello" } }, Store.chat.chat:read())

    Store.chat.chat:append({ role = "assistant", content = "hello" })
    assert.same({ { role = "user", content = "hello" }, { role = "assistant", content = "hello" } },
      Store.chat.chat:read())

    Store.chat.chat:append({ role = "assistant", content = " there" })
    assert.same({ { role = "user", content = "hello" }, { role = "assistant", content = "hello there" } },
      Store.chat.chat:read())

    Store.chat.chat:append({ role = "user", content = "cool" })
    assert.same({
        { role = "user",      content = "hello" },
        { role = "assistant", content = "hello there" },
        { role = "user",      content = "cool" }
      },
      Store.chat.chat:read()
    )
  end)

  it("Doesn't mind about unexpected message orderings", function()
    Store.chat.chat:append({ role = "assistant", content = "hello" })
    assert.same({ { role = "assistant", content = "hello" } }, Store.chat.chat:read())

    Store.chat.chat:append({ role = "user", content = "hello" })
    assert.same({ { role = "assistant", content = "hello" }, { role = "user", content = "hello" } },
      Store.chat.chat:read())

    Store.chat.chat:append({ role = "assistant", content = " there" })
    assert.same({
        { role = "assistant", content = "hello" },
        { role = "user",      content = "hello" },
        { role = "assistant", content = " there" }
      },
      Store.chat.chat:read()
    )
  end)
end)

describe("Store | jobs", function()
  before_each(function()
    Store:clear_job()
  end)

  it("takes one job", function()
    assert.equal(nil, Store:get_job())

    local job1 = { start = function() end, new = function() end }
    Store:register_job(job1)

    assert.equal(job1, Store:get_job())

    local job2 = { start = function() end, new = function() end }
    Store:register_job(job2)

    assert.equal(job2, Store:get_job())
  end)

  it('clears job', function()
    local job = { start = function() end, new = function() end }
    Store:register_job(job)

    Store:clear_job()
    assert.equal(nil, Store:get_job())
  end)
end)

describe("Store | llm stuff", function()
  before_each(function()
    Store:clear()
  end)

  it("set_llm assigns to local fields", function()
    Store:set_model("ollama", "llama3")
    local model_info = Store:get_model()
    assert.equal("ollama", model_info.provider)
    assert.equal("llama3", model_info.model)

    Store:set_model("openai", "gpt-4-turbo")
    model_info = Store:get_model()
    assert.equal("openai", model_info.provider)
    assert.equal("gpt-4-turbo", model_info.model)
  end)

  it("cycles through llm models", function()
    Store:set_models("ollama", { "m1", "m2", "m3" })
    Store:set_model("ollama", "m1")
    local models = Store:get_models("ollama")
    local first_model = Store:get_model().model
    local last_model = models[#models]

    Store:cycle_model_forward()
    assert.not_equal(first_model, Store:get_model().model)

    Store:cycle_model_backward()
    assert.equal(first_model, Store:get_model().model)

    -- And resets on bogus models
    Store:set_model("ollama", "not-present")
    Store:cycle_model_forward()
    assert.equal(first_model, Store:get_model().model)

    Store:set_model("ollama", "not-present")
    Store:cycle_model_backward()
    assert.equal(last_model, Store:get_model().model)
  end)

  it("shows convenient list of models with llm_model_strings", function()
    Store:set_models("ollama", { "m" })
    Store:set_models("openai", { "m" })

    assert(util.contains_line(Store:llm_model_strings(), "openai.m"))
    assert(util.contains_line(Store:llm_model_strings(), "openai.m"))
  end)

  it("set_models and get_models set and return the available models", function()
    Store:set_models("ollama", {})
    assert.same({}, Store:get_models("ollama"))
    Store:set_models("ollama", { "m1", "m2" })
    assert.same({ "m1", "m2" }, Store:get_models("ollama"))
  end)

  describe("correct_potentially_removed_current_model", function()
    it("does nothing if currently selected model is available", function()
      Store:set_models("ollama", {})
      Store:set_models("openai", { "gpt-4o-mini", "gpt-4o" })

      Store:set_model("openai", "gpt-4o")
      assert.equals("gpt-4o", Store:get_model().model)
      assert.equals("openai", Store:get_model().provider)

      -- Call the method to correct the potentially removed current model
      Store:correct_potentially_missing_current_model()

      -- Verify that it selects a default model since the current model is not available
      assert.equals("gpt-4o", Store:get_model().model)
      assert.equals("openai", Store:get_model().provider)
    end)

    it("corrects missing models with ones in defaults", function()
      Store:set_models("ollama", {})
      Store:set_models("openai", { "gpt-4o-mini", "gpt-4o" })

      Store:set_model("ollama", "not-present")
      assert.equals("not-present", Store:get_model().model)
      assert.equals("ollama", Store:get_model().provider)

      -- Call the method to correct the potentially removed current model
      Store:correct_potentially_missing_current_model()

      -- Verify that it selects a default model since the current model is not available
      assert.equals("gpt-4o-mini", Store:get_model().model)
      assert.equals("openai", Store:get_model().provider)
    end)

    it("picks first from available if no defaults are available", function()
      -- If no preferred are available, it goes to first in list
      Store:set_models("ollama", { "not-in-defaults", "not-in-defaults-either" })
      Store:set_models("openai", { "not-in-defaults-for-sure", "definitely-not-in-defaults" })

      Store:set_model("openai", "not-present")
      assert.equals(Store:get_model().model, "not-present")

      Store:correct_potentially_missing_current_model()

      assert.equals(Store:get_model().model, "not-in-defaults")
      assert.equals(Store:get_model().provider, "ollama")
    end)

  end)
end)

-- TODO Remove

-- -- Once when nvim is opened, and once again on every window open?
-- com.trigger_available_model_etl(function(openai_models, ollama_models)
--   Store.set_models("openai", openai_models) -- internally ensures selected model is still amongst available models
--   Store.set_models("ollama", ollama_models)
--   set_window_titles()
-- end)

-- -- Once when nvim is opened, and once again on every window open?
-- com.trigger_available_model_etl(
--   function(openai_models)
--     set_window_titles()
--   end,
--   function(ollama_models)
--     set_window_titles()
--   end
-- )
