---@diagnostic disable: undefined-global

-- local util = require("gpt.util")
local assert = require("luassert")
local gpt = require('gpt')

-- TODO Test running :GPT injects the correct is_visual_mode

describe(":GPT", function()
  it("Opens without erroring", function()
    vim.api.nvim_input(':GPT<CR>')
  end)
end)

describe("gpt.run (the main function)", function ()
  it("executes without error", function ()
    gpt.run({
      visual_mode = true
    })
  end)
end)

-- -- TODO I can't for the life of me get this working.
-- describe("get_visual_selection", function()
--   it("returns a table with the current visual selection", function()
--     -- Add some text to the buffer
--     vim.api.nvim_exec([[ call append(0, ["Nonsense text 1", "Nonsense text 2"]) ]], false)

--     -- Ensure that text was added
--     local current_buffer_contents = vim.api.nvim_buf_get_lines(0, 0, -1, false)
--     assert.same({ [1] = "Nonsense text 1", [2] = "Nonsense text 2", [3] = "" }, current_buffer_contents)

--     -- Delay to ensure the buffer is fully loaded
--     vim.api.nvim_command('sleep 100m')

--     -- Select all the text in the buffer
--     vim.api.nvim_input('ggVG')

--     -- Delay to ensure the selection is registered
--     vim.api.nvim_command('sleep 100m')

--     -- Ensure get_visual_selection is getting the whole selection
--     local selection = util.get_visual_selection()
--     assert.same({ start_line = 0, end_line = 2, start_column = 0, end_column = 2147483647 }, selection)
--   end)
-- end)

