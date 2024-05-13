---@diagnostic disable: undefined-global

local util = require("gpt.util")
local Store = require("gpt.store")
local assert = require("luassert")

describe("Store | setting / getting", function()
  before_each(function()
    Store.clear()
  end)

  it("sets and gets window content", function()
    Store.code.right.append("right")
    Store.code.right.append("right")

    Store.code.left.append("left")
    Store.code.left.append("left")

    Store.code.input.append("input")
    Store.code.input.append("input")

    Store.chat.input.append("input")
    Store.chat.input.append("input")

    Store.chat.chat.append({ role = "assistant", content = "chat" })
    Store.chat.chat.append({ role = "assistant", content = "chat" })

    assert.equal("rightright", Store.code.right.read())
    assert.equal("leftleft", Store.code.left.read())
    assert.equal("inputinput", Store.code.input.read())

    assert.equal("inputinput", Store.chat.input.read())
    assert.same({ { role = "assistant", content = "chatchat" } }, Store.chat.chat.read())
  end)

  it("sets and gets included files", function ()
    Store.code.append_file("lua/gpt/windows/code.lua")
    Store.code.append_file("lua/gpt/windows/chat.lua")

    Store.chat.append_file("lua/gpt/windows/code.lua")
    Store.chat.append_file("lua/gpt/windows/chat.lua")

    assert.same({ "lua/gpt/windows/code.lua", "lua/gpt/windows/chat.lua" }, Store.code.get_files())
    assert.same({ "lua/gpt/windows/code.lua", "lua/gpt/windows/chat.lua" }, Store.chat.get_files())
  end)
end)

describe("Store | messages", function()
  before_each(function()
    Store.chat.clear()
  end)

  it("starts with empty table", function()
    Store.chat.chat.append({ role = "assistant", content = "hello" })
    Store.chat.clear()
    assert.same({}, Store.chat.chat.read())
  end)

  it("clears messages", function()
    Store.chat.chat.append({ role = "assistant", content = "hello" })
    Store.chat.clear()
    assert.same({}, Store.chat.chat.read())
  end)

  it("Adds, joins, and gets messages", function()
    Store.chat.chat.append({ role = "user", content = "hello" })
    assert.same({ { role = "user", content = "hello" } }, Store.chat.chat.read())

    Store.chat.chat.append({ role = "assistant", content = "hello" })
    assert.same({ { role = "user", content = "hello" }, { role = "assistant", content = "hello" } },
      Store.chat.chat.read())

    Store.chat.chat.append({ role = "assistant", content = " there" })
    assert.same({ { role = "user", content = "hello" }, { role = "assistant", content = "hello there" } },
      Store.chat.chat.read())

    Store.chat.chat.append({ role = "user", content = "cool" })
    assert.same({
        { role = "user",      content = "hello" },
        { role = "assistant", content = "hello there" },
        { role = "user",      content = "cool" }
      },
      Store.chat.chat.read()
    )
  end)

  it("Doesn't mind about unexpected message orderings", function()
    Store.chat.chat.append({ role = "assistant", content = "hello" })
    assert.same({ { role = "assistant", content = "hello" } }, Store.chat.chat.read())

    Store.chat.chat.append({ role = "user", content = "hello" })
    assert.same({ { role = "assistant", content = "hello" }, { role = "user", content = "hello" } },
      Store.chat.chat.read())

    Store.chat.chat.append({ role = "assistant", content = " there" })
    assert.same({
        { role = "assistant", content = "hello" },
        { role = "user",      content = "hello" },
        { role = "assistant", content = " there" }
      },
      Store.chat.chat.read()
    )
  end)
end)

describe("Store | jobs", function()
  before_each(function()
    Store.clear_job()
  end)

  it("takes one job", function()
    assert.equal(nil, Store.get_job())

    local job1 = { start = function() end, new = function() end }
    Store.register_job(job1)

    assert.equal(job1, Store.get_job())

    local job2 = { start = function() end, new = function() end }
    Store.register_job(job2)

    assert.equal(job2, Store.get_job())
  end)

  it('clears job', function()
    local job = { start = function() end, new = function() end }
    Store.register_job(job)

    Store.clear_job()
    assert.equal(nil, Store.get_job())
  end)
end)

describe("Store | llm stuff", function ()
  it("set_llm assigns to local fields", function ()
    Store.set_llm("ollama", "llama3")
    assert.equal("ollama", Store.llm_provider)
    assert.equal("llama3", Store.llm_model)

    Store.set_llm("openai", "gpt-4-turbo")
    assert.equal("openai", Store.llm_provider)
    assert.equal("gpt-4-turbo", Store.llm_model)
  end)
end)
