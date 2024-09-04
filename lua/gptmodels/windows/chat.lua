local util = require('gptmodels.util')
local com = require('gptmodels.windows.common')
local Layout = require("nui.layout")
local Popup = require("nui.popup")
local llm = require("gptmodels.llm")
local Store = require("gptmodels.store")

local M = {}

local WINDOW_TITLE_PREFIX = "Chat w/ "

---@param bufnr integer
---@param messages LlmMessage[]
local safe_render_buffer_from_messages = function(bufnr, messages)
  if not bufnr then return end -- can happen when popup has been unmounted
  local buf_loaded = vim.api.nvim_buf_is_loaded(bufnr)
  local buf_valid = vim.api.nvim_buf_is_valid(bufnr)
  if not (buf_loaded and buf_valid) then return end

  local lines = {}
  for _, message in ipairs(messages) do
    local message_content = vim.split(message.content, "\n")
    lines = util.merge_tables(lines, message_content)
    table.insert(lines, "---")
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
end

---@param input_bufnr integer
---@param chat_bufnr integer
local on_CR = function(input_bufnr, chat_bufnr)
  local input_lines = vim.api.nvim_buf_get_lines(input_bufnr, 0, -1, false)
  local input_text = table.concat(input_lines, "\n")

  -- Clear input buf, store
  vim.api.nvim_buf_set_lines(input_bufnr, 0, -1, true, {})
  Store.chat.input:clear()

  Store.chat.chat:append({ role = "user", content = input_text })

  safe_render_buffer_from_messages(chat_bufnr, Store.chat.chat:read())

  -- Scroll to the bottom (in case user message goes past bottom of win)
  com.safe_scroll_to_bottom_when_user_not_present(Store.chat.chat.popup.winid or 1, Store.chat.chat.popup.bufnr)

  -- Attach included files
  local file_messages = {}
  for _, filename in ipairs(Store.chat:get_files()) do
    local file = io.open(filename, "r")
    if not file then break end
    local content = file:read("*all")
    file:close()

    table.insert(file_messages, {
      role = "system",
      content = filename .. ":\n\n" .. content
    })
  end

  local messages = util.merge_tables(Store.chat.chat:read(), file_messages)

  local job = llm.chat({
    llm = {
      stream = true,
      messages = messages,
    },
    on_read = function(err, message)
      if err then
        Store.chat.chat:append({ role = "assistant", content = err })
        safe_render_buffer_from_messages(Store.chat.chat.popup.bufnr, Store.chat.chat:read())
        return
      end

      -- No response _and_ no error? Weird. Happens though.
      if message then
        Store.chat.chat:append(message)
      end

      safe_render_buffer_from_messages(Store.chat.chat.popup.bufnr, Store.chat.chat:read())

      -- scroll to the bottom if the window's still open and the user is not in it
      -- (If they're in it, the priority is for them to be able to nav around and yank)
      com.safe_scroll_to_bottom_when_user_not_present(Store.chat.chat.popup.winid or 1, Store.chat.chat.popup.bufnr)
    end,
    on_end = function()
      Store:clear_job()
    end
  })

  Store:register_job(job)
end

---@param selection Selection | nil
---@return { input: NuiPopup, chat: NuiPopup }
function M.build_and_mount(selection)
  ---@type NuiPopup
  local chat = Popup(com.build_common_popup_opts(WINDOW_TITLE_PREFIX .. com.model_display_name()))
  ---@type NuiPopup
  local input = Popup(com.build_common_popup_opts("Prompt")) -- the Prompt part will be overwritten by calls to set_input_text

  -- available controls are found at the bottom of the input popup
  com.set_input_bottom_border_text(input)

  -- Register popups with store
  Store.chat.chat.popup = chat
  Store.chat.input.popup = input

  -- Fetch all models so user can work with what they have on their system
  com.trigger_models_etl(function()
    if chat.bufnr and chat.winid and vim.api.nvim_buf_is_valid(chat.bufnr) and vim.api.nvim_win_is_valid(chat.winid) then
      com.set_window_title(chat, 'Chat w/ ' .. com.model_display_name())
    end
  end)

  -- Input window is text with no syntax
  vim.bo[input.bufnr].filetype = 'txt'
  vim.bo[input.bufnr].syntax = ''

  -- Make input a 'scratch' buffer, effectively making it a temporary buffer
  vim.bo[input.bufnr].buftype = "nofile"

  -- Chat in markdown
  vim.bo[chat.bufnr].filetype = 'markdown'

  -- Add text selection to input buf
  if selection then
    -- If selected lines are given, it's like a new session, so we'll nuke all else
    local extent_job = Store:get_job()
    if extent_job then
      extent_job.die()
      vim.wait(100, function() return extent_job.done() end)
    end

    -- clear chat window
    vim.api.nvim_buf_set_lines(chat.bufnr, 0, -1, true, {})
    Store.chat.chat:clear()

    -- clear files
    Store.chat:clear_files()

    -- clear / add selection to input
    Store.chat.input:clear()
    vim.api.nvim_buf_set_lines(input.bufnr, 0, -1, true, selection.lines)

    -- Go to bottom of input and enter insert mode
    local keys = vim.api.nvim_replace_termcodes('<Esc>Go', true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', true)
  else
    -- If there's saved input, render that
    local input_content = Store.chat.input:read()
    if input_content then com.safe_render_buffer_from_text(input.bufnr, input_content) end

    -- If there's a chat history, open with that.
    safe_render_buffer_from_messages(chat.bufnr, Store.chat.chat:read())

    -- Get the files back
    com.set_input_top_border_text(input, Store.chat:get_files())
  end

  local layout = Layout(
    {
      position = "50%",
      relative = "editor",
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

  -- recalculate nui window when vim window resizes
  input:on("VimResized", function()
    layout:update()
  end)

  -- For input, save to populate on next open
  input:on("InsertLeave",
    function()
      local input_lines = vim.api.nvim_buf_get_lines(input.bufnr, 0, -1, true)
      Store.chat.input:clear()
      Store.chat.input:append(table.concat(input_lines, "\n"))
    end
  )

  -- keymaps
  vim.api.nvim_buf_set_keymap(input.bufnr, "n", "<CR>", "",
    {
      noremap = true,
      silent = true,
      callback = function()
        on_CR(input.bufnr, chat.bufnr)
      end
    }
  )

  local bufs = { chat.bufnr, input.bufnr }
  for i, buf in ipairs(bufs) do
    -- Tab cycles through windows
    vim.api.nvim_buf_set_keymap(buf, "n", "<Tab>", "", {
      noremap = true,
      silent = true,
      callback = function() com.cycle_tabs_forward(i, bufs) end,
    })

    -- Shift-Tab cycles through windows in reverse
    vim.api.nvim_buf_set_keymap(buf, "n", "<S-Tab>", "", {
      noremap = true,
      silent = true,
      callback = function() com.cycle_tabs_backward(i, bufs) end,
    })

    -- Ctl-n to reset session
    vim.api.nvim_buf_set_keymap(buf, "", "<C-n>", "", {
      noremap = true,
      silent = true,
      callback = function()
        Store.chat:clear()
        for _, bu in ipairs(bufs) do
          vim.api.nvim_buf_set_lines(bu, 0, -1, true, {})
        end
        com.set_input_top_border_text(input, Store.chat:get_files())
      end
    })

    -- Ctl-f to include files
    vim.api.nvim_buf_set_keymap(buf, "", "<C-f>", "", {
      noremap = true,
      silent = true,
      callback = com.launch_telescope_file_picker(function(filename)
        Store.chat:append_file(filename)
        com.set_input_top_border_text(input, Store.chat:get_files())
      end)
    })

    -- Ctl-g to clear files
    vim.api.nvim_buf_set_keymap(buf, "", "<C-g>", "", {
      noremap = true,
      silent = true,
      callback = function()
        Store.chat:clear_files()
        com.set_input_top_border_text(input, Store.chat:get_files())
      end
    })

    -- Ctrl-p to open model picker
    vim.api.nvim_buf_set_keymap(buf, "", "<C-p>", "", {
      noremap = true,
      silent = true,
      callback = function()
        com.launch_telescope_model_picker(function()
          com.set_window_title(chat, WINDOW_TITLE_PREFIX .. com.model_display_name())
        end)
      end
    })

    -- Ctrl-c to kill active job
    vim.api.nvim_buf_set_keymap(buf, "", "<C-c>", "", {
      noremap = true,
      silent = true,
      callback = function()
        if Store:get_job() then
          Store:get_job().die()
        end
      end
    })

    -- Ctrl-j to cycle forward through llms
    vim.api.nvim_buf_set_keymap(buf, "", "<C-j>", "", {
      noremap = true,
      silent = true,
      callback = function()
        Store:cycle_model_forward()
        com.set_window_title(chat, WINDOW_TITLE_PREFIX .. com.model_display_name())
      end
    })

    -- Ctrl-k to cycle forward through llms
    vim.api.nvim_buf_set_keymap(buf, "", "<C-k>", "", {
      noremap = true,
      silent = true,
      callback = function()
        Store:cycle_model_backward()
        com.set_window_title(chat, WINDOW_TITLE_PREFIX .. com.model_display_name())
      end
    })

    -- "q" exits from the thing
    vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
      noremap = true,
      silent = true,
      callback = function() layout:unmount() end,
    })
  end

  -- Once this mounts, our popups now have a winid for as long as the layout is mounted
  layout:mount()

  vim.wo[chat.winid].wrap = true
  vim.wo[input.winid].wrap = true

  -- Notify of any errors / warnings
  for level, message in pairs(com.check_deps()) do
    if message then
      vim.notify_once(message, vim.log.levels[level])
    end
  end

  return {
    input = input,
    chat = chat
  }
end

return M
