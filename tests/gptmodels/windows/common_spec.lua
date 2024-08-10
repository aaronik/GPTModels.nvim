---@diagnostic disable: undefined-global

local util = require("gptmodels.util")
local assert = require("luassert")
local code_window = require('gptmodels.windows.code')
local stub = require('luassert.stub')
local spy = require('luassert.spy')
local llm = require('gptmodels.llm')
local cmd = require('gptmodels.cmd')
local Store = require('gptmodels.store')
local ollama = require('gptmodels.providers.ollama')
local Popup = require('nui.popup')
local common = require('gptmodels.windows.common')


-- TODO: Add preflight check to both windows. Looks for curl, ollama, etc

describe("window common functions", function()
  describe("safe_render_buffer_from_text", function()
    it("doesnt cause errors when buffer is invalid", function()
      -- When buffer is whack
      local whack_buf = -1
      common.safe_render_buffer_from_text(whack_buf, "hi")

      -- When buffer is deleted
      local del_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_delete(del_buf, { force = true })
      common.safe_render_buffer_from_text(del_buf, "hi")

      -- When buffer is unloaded
      local unload_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_call(unload_buf, function() end) -- Unloads the buffer
      common.safe_render_buffer_from_text(unload_buf, "hi")

      -- When buffer is read only
      local ro_buf = vim.api.nvim_create_buf(false, true)
      vim.bo[ro_buf].modifiable = false
      common.safe_render_buffer_from_text(ro_buf, "hi")

      ---@diagnostic disable-next-line: param-type-mismatch
      common.safe_render_buffer_from_text(nil, "hi")
    end)
  end)

  describe("safe_render_buffer_from_lines", function()
    it("doesnt cause errors when buffer is invalid", function()
      -- When buffer is whack
      local whack_buf = -1
      common.safe_render_buffer_from_lines(whack_buf, { "hi" })

      -- When buffer is deleted
      local del_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_delete(del_buf, { force = true })
      common.safe_render_buffer_from_lines(del_buf, { "hi" })

      -- When buffer is unloaded
      local unload_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_call(unload_buf, function() end) -- Unloads the buffer
      common.safe_render_buffer_from_lines(unload_buf, { "hi" })

      -- When buffer is read only
      local ro_buf = vim.api.nvim_create_buf(false, true)
      vim.bo[ro_buf].modifiable = false
      common.safe_render_buffer_from_lines(ro_buf, { "hi" })

      ---@diagnostic disable-next-line: param-type-mismatch
      common.safe_render_buffer_from_lines(nil, { "hi" })
    end)
  end)

  describe("set_input_bottom_border_text", function()
    it("sets border text when no extra commands are given", function()
      ---@type NuiPopup
      local popup = Popup({ title = "Test" })
      local set_text_stub = stub(popup.border, 'set_text')
      common.set_input_bottom_border_text(popup)
      assert.stub(set_text_stub).was_called(1)
    end)

    it("sets border text when no extra commands are given", function()
      ---@type NuiPopup
      local popup = Popup({ title = "Test" })
      local extra_commands = { "some command" }
      local set_text_stub = stub(popup.border, 'set_text')
      common.set_input_bottom_border_text(popup, extra_commands)
      assert.stub(set_text_stub).was_called(1)
    end)
  end)

  describe("set_input_top_border_text", function()
    it("sets border text without given files", function()
      ---@type NuiPopup
      local popup = Popup({ title = "Test" })
      local set_text_stub = stub(popup.border, 'set_text')
      common.set_input_top_border_text(popup, {})
      assert.stub(set_text_stub).was_called(1)
    end)

    it("sets border text with given files", function()
      ---@type NuiPopup
      local popup = Popup({ title = "Test" })
      local set_text_stub = stub(popup.border, 'set_text')
      common.set_input_top_border_text(popup, { "file one", "file two" })
      assert.stub(set_text_stub).was_called(1)
    end)
  end)
end)
