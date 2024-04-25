local util = require('gpt.util')
local com  = require('gpt.window.common')
local Layout = require("nui.layout")
local Popup = require("nui.popup")

local M = {}

function _GPTOnEditWindowCR(input_bufnr, code_bufnr)
  local input_text = vim.api.nvim_buf_get_lines(input_bufnr, 0, -1, false)
  local code_text = vim.api.nvim_buf_get_lines(code_bufnr, 0, -1, false)

  local text = input_text .. "\n" .. code_text

  -- Add input text to chat
  vim.api.nvim_buf_set_lines(text, -1, -1, true, input_text)

  -- Clear input
  vim.api.nvim_buf_set_lines(input_bufnr, 0, -1, true, {})
end

function M.build_and_mount(selected_text)
  local top_left_popup = Popup(com.build_common_popup_opts("Current"))
  local top_right_popup = Popup(com.build_common_popup_opts("Edits"))
  local input = Popup(com.build_common_popup_opts("Prompt"))

  -- Turn off syntax highlighting for input buffer.
  -- TODO Make sure this doesn't for some reason cause treesitter to look
  -- for markdown!
  vim.api.nvim_buf_set_option(input.bufnr, 'filetype', 'txt')
  vim.api.nvim_buf_set_option(input.bufnr, 'syntax', '')

  -- Make input a 'scratch' buffer, effectively making it a temporary buffer
  vim.api.nvim_buf_set_option(input.bufnr, "buftype", "nofile")

  -- Set buffers to same filetype as current file, for highlighting
  vim.api.nvim_buf_set_option(top_left_popup.bufnr, 'filetype', vim.bo.filetype)
  vim.api.nvim_buf_set_option(top_right_popup.bufnr, 'filetype', vim.bo.filetype)

  -- The windows are small, so let's not wrap TODO Couldn't figure this out in 5 mins of looking

  -- Theoretically we'll always have selected_text at this point, but ok to defend
  if selected_text then
    vim.api.nvim_buf_set_lines(top_left_popup.bufnr, 0, -1, true, selected_text)
  end

  -- TODO The goal is to call a function when <CR> is pressed in normal mode within this popup.
  -- This way works, but it's gross. I'd much rather something like popup:on(<CR>, whatever())
  vim.api.nvim_buf_set_keymap(
    input.bufnr,
    "n",
    "<CR>",
    ":lua _GPTOnEditWindowCR(" .. input.bufnr .. ", " .. top_left_popup.bufnr .. ")<CR>",
    { noremap = true, silent = true }
  )

  local layout = Layout(
    {
      position = "50%",
      size = {
        width = "90%",
        height = "90%",
      },
    },
    Layout.Box({
      Layout.Box({
        Layout.Box(top_left_popup, { size = "50%" }),
        Layout.Box(top_right_popup, { size = "50%" }),
      }, { dir = "row", size = "80%" }),
      Layout.Box(input, { size = "22%" }),
    }, { dir = "col" })
  )

  layout:mount()
end

return M
