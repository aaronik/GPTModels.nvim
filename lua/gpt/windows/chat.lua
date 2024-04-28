local util = require('gpt.util')
local com = require('gpt.windows.common')
local Layout = require("nui.layout")
local Popup = require("nui.popup")
local ollama = require("gpt.adapters.ollama")

local M = {}

---@param input_bufnr integer
---@param chat_bufnr integer
local on_CR = function(input_bufnr, chat_bufnr)
  local input_lines = vim.api.nvim_buf_get_lines(input_bufnr, 0, -1, false)
  table.insert(input_lines, "")
  table.insert(input_lines, "")

  -- Add input text to chat
  vim.api.nvim_buf_set_lines(chat_bufnr, -1, -1, true, input_lines)

  -- Clear input
  vim.api.nvim_buf_set_lines(input_bufnr, 0, -1, true, {})

  local chat_lines = vim.api.nvim_buf_get_lines(chat_bufnr, 0, -1, true)
  local chat_text = table.concat(chat_lines, "\n")

  ollama.make_request(table.concat(input_lines, "\n"), "llama3", function(chunk)
      chat_text = chat_text .. chunk
      vim.api.nvim_buf_set_lines(chat_bufnr, 0, -1, true, vim.split(chat_text, "\n"))
    end,
    function()
      util.log('--END--')
    end)
end

---@return { input_bufnr: integer, chat_bufnr: integer }
function M.build_and_mount()
  local chat = Popup(com.build_common_popup_opts("Chat"))
  local input = Popup(com.build_common_popup_opts("Prompt"))

  -- Input window is text with no syntax
  vim.api.nvim_buf_set_option(input.bufnr, 'filetype', 'txt')
  vim.api.nvim_buf_set_option(input.bufnr, 'syntax', '')

  -- Make input a 'scratch' buffer, effectively making it a temporary buffer
  vim.api.nvim_buf_set_option(input.bufnr, "buftype", "nofile")

  -- TODO The goal is to call a function when <CR> is pressed in normal mode within this popup.
  -- This way works, but it's gross. I'd much rather something like popup:on(<CR>, whatever()),
  -- and run lua code from there. Don't want to convert everything to strings to pass it.
  vim.api.nvim_buf_set_keymap(
    input.bufnr,
    "n",
    "<CR>",
    "",
    { noremap = true, silent = true, callback = function() on_CR(input.bufnr, chat.bufnr) end }
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

  -- start window in insert mode
  vim.api.nvim_command('startinsert')

  -- keymaps
  local bufs = { chat.bufnr, input.bufnr }
  for i, buf in ipairs(bufs) do
    -- Tab cycles through windows
    vim.api.nvim_buf_set_keymap(buf, "n", "<Tab>", "", {
      noremap = true,
      silent = true,
      callback = function()
        local next_buf_index = (i % #bufs) + 1
        local next_win = vim.fn.bufwinid(bufs[next_buf_index])
        vim.api.nvim_set_current_win(next_win)
      end
    })

    -- Shift-Tab cycles through windows in reverse
    vim.api.nvim_buf_set_keymap(buf, "n", "<S-Tab>", "", {
      noremap = true,
      silent = true,
      callback = function()
        local prev_buf_index = (i - 2) % #bufs + 1
        local prev_win = vim.fn.bufwinid(bufs[prev_buf_index])
        vim.api.nvim_set_current_win(prev_win)
      end
    })

    -- "q" exits from the thing
    -- TODO remove or test
    vim.api.nvim_buf_set_keymap(buf, "n", "q", "",
      { noremap = true, silent = true, callback = function() layout:unmount() end })
  end

  return {
    input_bufnr = input.bufnr,
    chat_bufnr = chat.bufnr
  }
end

return M
