---@diagnostic disable: undefined-global

local util = require("gpt.util")
local assert = require("luassert")
local gpt = require('gpt')

describe("gpt.run (the main function)", function()

  -- Set current window height, otherwise it defaults to 0 and nui.layout complains about not having a pos integer height
  before_each(function()
    vim.api.nvim_win_set_height(0, 30)
  end)

  it("opens in visual mode without error", function()
    gpt.run({ visual_mode = true })
  end)

  it("opens in normal mode without error", function()
    gpt.run({ visual_mode = false })
  end)
end)

-- -- TODO I can't for the life of me get this working.
-- describe("util.get_visual_selection", function()
--   it("returns a table with the current visual selection", function()
--     -- Create a new buffer
--     local test_buf = vim.api.nvim_create_buf(false, true)

--     -- Switch to the new buffer
--     vim.api.nvim_set_current_buf(test_buf)

--     local buf = vim.api.nvim_get_current_buf()

--     local lines = { "Nonsense text 1", "Nonsense text 2" }

--     -- Append lines at the start of the buffer
--     -- nvim_buf_set_lines arguments: buffer handle, start index, end index, strict indexing, lines to set
--     vim.api.nvim_buf_set_lines(buf, 0, 0, false, lines)

--     -- Ensure that text was added
--     local current_buffer_contents = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
--     assert.same({ [1] = "Nonsense text 1", [2] = "Nonsense text 2", [3] = "" }, current_buffer_contents)

--     -- Select all the text in the buffer
--     vim.api.nvim_input('ggVG')

--     -- Ensure get_visual_selection is getting the whole selection
--     local selection = get_visual_selection()
--     assert.same({ start_line = 0, end_line = 2, start_column = 0, end_column = 2147483647 }, selection)
--   end)
-- end)
