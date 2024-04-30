local util = require('gpt.util')
local com = require('gpt.windows.common')
local Layout = require("nui.layout")
local Popup = require("nui.popup")
local llm = require("gpt.llm")

local M = {}

-- TODO on_exit call job:shutdown()

-- TODO This lives wherever our state lives
---@type LlmMessage[]
local messages = {}

---@param input_bufnr integer
---@param chat_bufnr integer
local on_CR = function(input_bufnr, chat_bufnr)
  local input_lines = vim.api.nvim_buf_get_lines(input_bufnr, 0, -1, false)
  local input_text = table.concat(input_lines, "\n")

  -- Clear input buf
  vim.api.nvim_buf_set_lines(input_bufnr, 0, -1, true, {})

  ---@param bufnr integer
  ---@param messages LlmMessage[]
  local render_buffer_from_messages = function (bufnr, messages)
    local lines = {}
    for _, message in ipairs(messages) do
      local message_content = vim.split(message.content, "\n")
      lines = util.merge_tables(lines, message_content)
      table.insert(lines, "---")
    end
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
  end

  table.insert(messages, { role = "user", content = input_text })
  render_buffer_from_messages(chat_bufnr, messages)

  llm.make_request({
    llm = {
      stream = true,
      messages = messages,
      model = "llama3"
    },
    kind = "chat",
    on_response = function(message)
      -- If the most recent message is not from the user, then we'll assume the llm is in the process of giving a response.
      if messages[#messages].role ~= "user" then
        messages[#messages].content = messages[#messages].content .. message.content
      else
        table.insert(messages, message)
      end

      render_buffer_from_messages(chat_bufnr, messages)
    end,
    on_end = function()
    end
  })
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
