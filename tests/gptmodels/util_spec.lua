---@diagnostic disable: undefined-global

local util = require("gptmodels.util")
local stub = require('luassert.stub')
local assert = require("luassert")

describe("util", function()
  describe("contains_line", function()
    assert(util.contains_line({ "has", "also" }, "has"))
    assert.False(util.contains_line({ "doesnt" }, "has"))
  end)

  describe("guid", function()
    it("never repeats", function()
      local guids = {}
      for _ = 1, 1000 do
        guids[util.guid()] = true
      end

      local count = 0
      for _ in pairs(guids) do
        count = count + 1
      end

      assert.equal(1000, count)
    end)
  end)

  describe("log", function()
    it("works", function()
      local io_open_stub = stub(io, "open")

      ---@type string[]
      local writes = {}
      local num_flushes = 0
      local num_closes = 0

      local log_file = {
        -- _ is because write is a _method_, log_file:write, so it gets self arg
        write = function(_, arg1, arg2)
          table.insert(writes, arg1)
          table.insert(writes, arg2)
        end,
        flush = function()
          num_flushes = num_flushes + 1
        end,
        close = function()
          num_closes = num_closes + 1
        end
      }

      io_open_stub.returns(log_file)

      util.log(1, 2, 3, 4, 5)

      assert.same({ "1\n", "2\n", "3\n", "4\n", "5\n", }, writes)
      assert.equal(1, num_flushes)
      assert.equal(1, num_closes)
    end)
  end)

  describe("merge_tables", function()
    it("merges N hash style tables", function()
      local a = { a = true }
      local b = { b = true }
      local c = { c = true }
      local d = util.merge_tables(a, b, c)
      assert.same({ a = true, b = true, c = true }, d)
    end)

    it("merges multiple array style tables", function()
      local a = { true }
      local b = { false }
      local c = { true, false }
      local d = util.merge_tables(a, b, c)
      assert.same({ true, false, true, false }, d)
    end)

    it("merges combo style tables", function()
      local a = { a = true }
      local b = { false, false }
      local c = { true, true }
      local d = util.merge_tables(a, b, c)
      assert.same({ a = true, false, false, true, true }, d)
    end)

    it("does not overwrite arguments", function()
      local a = { a = true }
      local b = { b = true }
      util.merge_tables(a, b)
      assert.same({ a = true }, a)
      assert.same({ b = true }, b)
    end)
  end)

  describe("get_visual_selection", function()
    it("returns the correctly shaped object", function()
      local res = util.get_visual_selection()
      assert.is_true(res.start_line ~= nil)
      assert.is_true(res.end_line ~= nil)
      assert.is_true(res.start_column ~= nil)
      assert.is_true(res.end_column ~= nil)
      assert.is_true(res.lines ~= nil)
    end)
  end)

  describe("ensure_env_var", function()
    it("returns true", function()
      -- always set
      local res = util.has_env_var("SHELL")
      assert.is_true(res)
    end)

    it("returns false", function()
      local res = util.has_env_var("IM_SUPER_SURE_THIS_ENV_VAR_WONT_BE_SET_FR_FR")
      assert.is_false(res)
    end)
  end)

  describe("get_relevant_diagnostic_text", function()
    it("formats and returns relevant diagnostic messages within the given line range", function()
      local diagnostics = {
        { severity = 1, lnum = 1, end_lnum = 1, message = "Error on line 1\n  Second line of message" },
        { severity = 2, lnum = 2, end_lnum = 2, message = "Warning on line 2" },
        { severity = 3, lnum = 3, end_lnum = 3, message = "Info on line 3" },
      }

      ---@type Selection
      local selection = {
        start_line = 1,
        end_line = 2,
        lines = {
          "error_code()",
          "warning_code()",
          "info_code()",
        },
        start_column = 0,
        end_column = 0
      }

      local expected_output = {
        "Please fix the following 2 LSP Diagnostic(s) in this code:",
        "",
        "[LINE(S)]",
        "error_code()",
        "[ERROR]",
        "Error on line 1",
        "  Second line of message",
        "",
        "[LINE(S)]",
        "warning_code()",
        "[WARN]",
        "Warning on line 2"
      }

      local result = util.get_relevant_diagnostics(diagnostics, selection)
      assert.are.same(expected_output, result)
    end)
  end)

  describe("get_diff_from_text_chunk", function()
    it("gets a diff", function()
      local chunk = [[
not included
```diff
included
```
also not included
      ]]
      local diff = util.get_diff_from_text_chunk(chunk)
      assert.same("included", diff)
    end)

    it("respects relative indentation", function()
      local chunk = [[
not included
```diff
not indented
  indented
```
also not included
      ]]
      local diff = util.get_diff_from_text_chunk(chunk)
      assert.same("not indented\n  indented", diff)
    end)

    it("respects absolute indentation", function()
      local chunk = [[
not included
```diff
  indented
```
also not included
      ]]
      local diff = util.get_diff_from_text_chunk(chunk)
      assert.same("  indented", diff)
    end)

    it("doesn't explode when there're no ```diff or ``` included", function()
      local chunk = "no diff here"
      local diff = util.get_diff_from_text_chunk(chunk)
      assert.is_nil(diff)
    end)

    it("handles when the given text starts with ```diff", function()
      local chunk = [[
```diff
buncha diff stuff wooooo
```
      ]]
      local diff = util.get_diff_from_text_chunk(chunk)
      assert.same("buncha diff stuff wooooo", diff)
    end)
  end)

  describe("apply_diff", function()
    it("takes file content and a unified diff format diff, and applies the diff", function()
      local content = [[
content line 1
content line 2
content line 3
      ]]

      local diff = [[
--- file	2024-10-20 13:28:39
+++ file	2024-10-20 13:30:50
@@ -1,3 +1,2 @@
 content line 1
-content line 2
 content line 3
]]

      local expected = [[
content line 1
content line 3
      ]]

      local result = util.apply_diff(content, diff)
      assert.same(expected, result)
    end)
  end)
end)
