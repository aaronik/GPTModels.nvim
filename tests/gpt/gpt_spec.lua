---@diagnostic disable: undefined-global

local gpt = require('gpt')

function CommonBefore()
  before_each(function()
    -- Set current window dims, otherwise it defaults to 0 and nui.layout complains about not having a pos integer height
    vim.api.nvim_win_set_height(0, 100)
    vim.api.nvim_win_set_width(0, 100)
  end)
end

describe("gpt.run (the main function)", function()
  CommonBefore()

  it("opens in visual mode without error", function()
    gpt.run({ visual_mode = true })
  end)

  it("opens in normal mode without error", function()
    gpt.run({ visual_mode = false })
  end)
end)
