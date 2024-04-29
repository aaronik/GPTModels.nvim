---@diagnostic disable: undefined-global

local util = require("gpt.util")
local assert = require("luassert")

describe("util", function()
  describe("log", function()
    it("works", function()
      -- TODO stub io.{open,write,flush,close}; ensure write gets variadic arguments
      util.log("--Test run--")
    end)
  end)

  describe("merge_tables", function()
    it("merges hash style tables", function()
      local a = { a = true }
      local b = { b = true }
      local c = util.merge_tables(a, b)
      assert.same(c, { a = true, b = true })
    end)

    it("merges array style tables", function()
      local a = { true }
      local b = { false }
      local c = util.merge_tables(a, b)
      assert.same(c, { true, false })
    end)

    it("merges combo style tables", function()
      local a = { a = true }
      local b = { false }
      local c = util.merge_tables(a, b)
      assert.same(c, { a = true, false })
    end)

    it("merges combo style tables", function()
      local a = { a = true }
      local b = { false }
      local c = util.merge_tables(a, b)
      assert.same(c, { a = true, false })
    end)

    it("does not overwrite arguments", function ()
      local a = { a = true }
      local b = { b = true }
      util.merge_tables(a, b)
      assert.same(a, { a = true })
      assert.same(b, { b = true })
    end)
  end)

  describe("get_visual_selection", function()
    it("returns the correctly shaped object", function()
      local res = util.get_visual_selection()
      assert.is_true(res.start_line ~= nil)
      assert.is_true(res.end_line ~= nil)
      assert.is_true(res.start_column ~= nil)
      assert.is_true(res.end_column ~= nil)
      assert.is_true(res.text ~= nil)
    end)
  end)

  -- TODO I can't for the life of me get this working.
  describe("util.get_visual_selection", function()
    pending("returns a table with the current visual selection", function()
      -- Create a new buffer
      local test_buf = vim.api.nvim_create_buf(false, true)

      -- Switch to the new buffer
      vim.api.nvim_set_current_buf(test_buf)
      vim.api.nvim_win_set_height(0, 30)
      vim.api.nvim_win_set_width(0, 300)

      local buf = vim.api.nvim_get_current_buf()

      local lines = { "Nonsense text 1", "Nonsense text 2" }
      local expected_lines = { [1] = "Nonsense text 1", [2] = "Nonsense text 2", [3] = "" }

      -- Append lines at the start of the buffer
      -- nvim_buf_set_lines arguments: buffer handle, start index, end index, strict indexing, lines to set
      vim.api.nvim_buf_set_lines(buf, 0, 0, false, lines)

      -- Ensure that text was added
      local current_buffer_contents = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      assert.same(expected_lines, current_buffer_contents)

      -- Select all the text in the buffer
      vim.api.nvim_feedkeys('ggVG', 'mtx', true)

      -- Ensure get_visual_selection is getting the whole selection
      local selection = util.get_visual_selection()
      assert.same({ start_line = 0, end_line = 2, start_column = 0, end_column = 2147483647, text = expected_lines },
        selection)
    end)
  end)
end)
