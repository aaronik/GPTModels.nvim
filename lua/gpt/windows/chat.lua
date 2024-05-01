local util = require('gpt.util')
local com = require('gpt.windows.common')
local Layout = require("nui.layout")
local Popup = require("nui.popup")
local llm = require("gpt.llm")
local Store = require("gpt.store")

local M = {}

---@param bufnr integer
---@param messages LlmMessage[]
local render_buffer_from_messages = function(bufnr, messages)
  local lines = {}
  for _, message in ipairs(messages) do
    local message_content = vim.split(message.content, "\n")
    lines = util.merge_tables(lines, message_content)
    table.insert(lines, "---")
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
end

-- TODO when window is closed call job:shutdown()
-- TODO auto-scroll (lua fn for ctl-e?) when focus is not in chat window

---@param input_bufnr integer
---@param chat_bufnr integer
local on_CR = function(input_bufnr, chat_bufnr)
  local input_lines = vim.api.nvim_buf_get_lines(input_bufnr, 0, -1, false)
  local input_text = table.concat(input_lines, "\n")

  -- Clear input buf
  vim.api.nvim_buf_set_lines(input_bufnr, 0, -1, true, {})

  Store.register_message({ role = "user", content = input_text })
  render_buffer_from_messages(chat_bufnr, Store.get_messages())

  local jorb = llm.chat({
    llm = {
      stream = true,
      messages = Store.get_messages(),
      model = "llama3"
    },
    kind = "chat",
    on_response = function(message)
      Store.register_message(message)
      render_buffer_from_messages(chat_bufnr, Store.get_messages())
    end,
    on_end = function()
      Store.clear_job()
    end
  })

  Store.register_job(jorb)
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

  local function tab_cb(i, bufs)
    local next_buf_index = (i % #bufs) + 1
    local next_win = vim.fn.bufwinid(bufs[next_buf_index])
    vim.api.nvim_set_current_win(next_win)
  end

  local function stab_cb(i, bufs)
    local next_buf_index = (i % #bufs) + 1
    local next_win = vim.fn.bufwinid(bufs[next_buf_index])
    vim.api.nvim_set_current_win(next_win)
  end

  local function q_cb(layout)
    -- TODO export to util again or something

    -- If there's an active request when this closes, cancel it
    -- TODO test
    -- TODO unfortunately this does not seem to stop the request from continuing to fire.
    local jorb = Store.get_job()
    if jorb ~= nil then
      os.execute("kill -2 " .. tostring(jorb.pid_int))     -- This is aweful and i hope it dies
      -- jorb:shutdown() -- does not work
    end
    layout:unmount()
  end

  -- keymaps
  local bufs = { chat.bufnr, input.bufnr }
  for i, buf in ipairs(bufs) do
    -- Tab cycles through windows
    vim.api.nvim_buf_set_keymap(buf, "n", "<Tab>", "", {
      noremap = true,
      silent = true,
      callback = function() tab_cb(i, bufs) end,
    })

    -- Shift-Tab cycles through windows in reverse
    vim.api.nvim_buf_set_keymap(buf, "n", "<S-Tab>", "", {
      noremap = true,
      silent = true,
      callback = function() stab_cb(i, bufs) end,
    })

    -- "q" exits from the thing
    -- TODO remove or test
    vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
      noremap = true,
      silent = true,
      callback = function() q_cb(layout) end,
    })
  end

  return {
    input_bufnr = input.bufnr,
    chat_bufnr = chat.bufnr
  }
end

return M
