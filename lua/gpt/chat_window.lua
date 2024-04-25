local util = require('gpt.util')
local event = require("nui.utils.autocmd").event
local com = require('gpt.window.common')
local Layout = require("nui.layout")
local Popup = require("nui.popup")

local M = {}

function _GPTOnChatWindowCR(input_bufnr, chat_bufnr)
  local input_text = vim.api.nvim_buf_get_lines(input_bufnr, 0, -1, false)

  -- Add input text to chat
  vim.api.nvim_buf_set_lines(chat_bufnr, -1, -1, true, input_text)

  -- Clear input
  vim.api.nvim_buf_set_lines(input_bufnr, 0, -1, true, {})
end

function M.build_and_mount()
  local chat = Popup(com.build_common_popup_opts("Chat"))
  local input = Popup(com.build_common_popup_opts("Prompt"))

  -- Input window is text with no syntax
  vim.api.nvim_buf_set_option(input.bufnr, 'filetype', 'txt')
  vim.api.nvim_buf_set_option(input.bufnr, 'syntax', '')

  -- Make input a 'scratch' buffer, effectively making it a temporary buffer
  vim.api.nvim_buf_set_option(input.bufnr, "buftype", "nofile")

  -- Chat window will be markdown?
  vim.api.nvim_buf_set_option(chat.bufnr, 'filetype', 'md')

  -- TODO The goal is to call a function when <CR> is pressed in normal mode within this popup.
  -- This way works, but it's gross. I'd much rather something like popup:on(<CR>, whatever()),
  -- and run lua code from there. Don't want to convert everything to strings to pass it.
  vim.api.nvim_buf_set_keymap(
    input.bufnr,
    "n",
    "<CR>",
    ":lua _GPTOnChatWindowCR(" .. input.bufnr .. ", " .. chat.bufnr .. ")<CR>",
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
      Layout.Box(chat, { size = "80%" }),
      Layout.Box(input, { size = "22%" }),
    }, { dir = "col" })
  )

  layout:mount()
end

return M
