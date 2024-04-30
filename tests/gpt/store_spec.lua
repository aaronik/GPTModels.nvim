---@diagnostic disable: undefined-global

local util = require("gpt.util")
local assert = require("luassert")
local Store = require("gpt.store")

describe("store", function()
    it("Adds, joins, and gets messages", function()
      Store.register_message({ role = "user", content = "hello" })
      assert.same(Store.get_messages(), { { role = "user", content = "hello" } })

      Store.register_message({ role = "assistant", content = "hello" })
      assert.same(Store.get_messages(), { { role = "user", content = "hello" }, { role = "assistant", content = "hello" } })

      Store.register_message({ role = "assistant", content = " there" })
      assert.same(Store.get_messages(), { { role = "user", content = "hello" }, { role = "assistant", content = "hello there" } })
    end)
end)
