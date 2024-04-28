---@diagnostic disable: undefined-global

local gpt = require('gpt')

describe("gpt.run (the main function)", function()
  it("opens in visual mode without error", function()
    gpt.run({ visual_mode = true })
  end)

  it("opens in normal mode without error", function()
    gpt.run({ visual_mode = false })
  end)
end)
