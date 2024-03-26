---@diagnostic disable: undefined-global

local module = require("../lua/gpt.module")
local vim = vim -- TODO Get this to provide type feedback
local assert = require("luassert")
local spy = require('luassert.spy')

-- TODO I can't for the life of me get this working.
describe("get_visual_selection", function()
  it("returns a table with the current visual selection", function()
    -- Add some text to the buffer
    vim.api.nvim_exec([[ call append(0, ["Nonsense text 1", "Nonsense text 2"]) ]], false)

    -- Ensure that text was added
    local current_buffer_contents = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.same({ [1] = "Nonsense text 1", [2] = "Nonsense text 2", [3] = "" }, current_buffer_contents)

    -- Delay to ensure the buffer is fully loaded
    vim.api.nvim_command('sleep 100m')

    -- Select all the text in the buffer
    vim.api.nvim_input('ggVG')

    -- Delay to ensure the selection is registered
    vim.api.nvim_command('sleep 100m')

    -- Ensure get_visual_selection is getting the whole selection
    local selection = module.get_visual_selection()
    assert.same({ start_line = 0, end_line = 2, start_column = 0, end_column = 2147483647 }, selection)
  end)
end)

