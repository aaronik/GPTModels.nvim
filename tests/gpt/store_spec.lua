---@diagnostic disable: undefined-global

local util = require("gpt.util")
local assert = require("luassert")
local Store = require("gpt.store")

describe("store", function()
  before_each(function()
    Store.reset_messages()
  end)

  it("Adds, joins, and gets messages", function()
    Store.register_message({ role = "user", content = "hello" })
    assert.same({ { role = "user", content = "hello" } }, Store.get_messages())

    Store.register_message({ role = "assistant", content = "hello" })
    assert.same({ { role = "user", content = "hello" }, { role = "assistant", content = "hello" } }, Store.get_messages())

    Store.register_message({ role = "assistant", content = " there" })
    assert.same({ { role = "user", content = "hello" }, { role = "assistant", content = "hello there" } },
      Store.get_messages())

    Store.register_message({ role = "user", content = "cool" })
    assert.same({
        { role = "user",      content = "hello" },
        { role = "assistant", content = "hello there" },
        { role = "user",      content = "cool" }
      },
      Store.get_messages()
    )
  end)

  it("Doesn't mind about unexpected orderings", function()
    Store.register_message({ role = "assistant", content = "hello" })
    assert.same({ { role = "assistant", content = "hello" } }, Store.get_messages())

    Store.register_message({ role = "user", content = "hello" })
    assert.same({ { role = "assistant", content = "hello" }, { role = "user", content = "hello" } }, Store.get_messages())

    Store.register_message({ role = "assistant", content = " there" })
    assert.same({
        { role = "assistant", content = "hello" },
        { role = "user",      content = "hello" },
        { role = "assistant", content = " there" }
      },
      Store.get_messages()
    )
  end)

  it("resets messages", function()
    Store.register_message({ role = "assistant", content = "hello" })
    Store.reset_messages()
    assert.same({}, Store.get_messages())
  end)
end)
