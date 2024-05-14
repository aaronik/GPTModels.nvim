local util = require('gpt.util')
local com = require('gpt.windows.common')
local Layout = require("nui.layout")
local Popup = require("nui.popup")
local llm = require("gpt.llm")
local Store = require("gpt.store")

local M = {}

---@param bufnr integer
---@param messages LlmMessage[]
local safe_render_buffer_from_messages = function(bufnr, messages)
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

-- TODO when window is closed call job:shutdown()
-- TODO auto-scroll (lua fn for ctl-e?) when focus is not in chat window

---@param input_bufnr integer
---@param chat_bufnr integer
local on_CR = function(input_bufnr, chat_bufnr, chat_winid)
  local input_lines = vim.api.nvim_buf_get_lines(input_bufnr, 0, -1, false)
  local input_text = table.concat(input_lines, "\n")

  -- Clear input buf
  vim.api.nvim_buf_set_lines(input_bufnr, 0, -1, true, {})

  Store.chat.chat.append({ role = "user", content = input_text })
  safe_render_buffer_from_messages(chat_bufnr, Store.chat.chat.read())

  local file_messages = {}
  for _, filename in ipairs(Store.chat.get_files()) do
    local file = io.open(filename, "r")
    if not file then break end
    local content = file:read("*all")
    file:close()

    table.insert(file_messages, {
      role = "system",
      content = filename .. ":\n\n" .. content
    })
  end
  local messages = util.merge_tables(Store.chat.chat.read(), file_messages)

  local jorb = llm.chat({
    llm = {
      stream = true,
      messages = messages,
    },
    on_read = function(err, message)
      -- Show errors to users. Inline is convenient for now.
      if err then
        Store.chat.chat.append({ role = "assistant", content = err })
        safe_render_buffer_from_messages(Store.chat.chat.bufnr, Store.chat.chat.read())
        return
      end

      -- No response _and_ no error? Weird. Happens though.
      if message then
        Store.chat.chat.append(message)
      end

      safe_render_buffer_from_messages(Store.chat.chat.bufnr, Store.chat.chat.read())

      -- scroll to the bottom if the window's still open and the user is not in it
      -- (If they're in it, the priority is for them to be able to nav around and yank)
      if vim.api.nvim_win_is_valid(chat_winid) and vim.api.nvim_get_current_win() ~= chat_winid then
        vim.api.nvim_win_set_cursor(chat_winid,
          { vim.api.nvim_buf_line_count(chat_bufnr), 0 }
        )
      end
    end,
    on_end = function()
      Store.clear_job()
    end
  })

  Store.register_job(jorb)
end

local function on_tab(i, bufs)
  local next_buf_index = (i % #bufs) + 1
  local next_win = vim.fn.bufwinid(bufs[next_buf_index])
  vim.api.nvim_set_current_win(next_win)
end

local function on_s_tab(i, bufs)
  local next_buf_index = (i % #bufs) + 1
  local next_win = vim.fn.bufwinid(bufs[next_buf_index])
  vim.api.nvim_set_current_win(next_win)
end

---@param input any -- this is a popup, wish they were typed
local function set_input_text(input)
  local files = Store.chat.get_files()
  if #files == 0 then
    input.border:set_text(
      "top",
      " Prompt ",
      "center"
    )
  else
    local files_string = table.concat(files, ", ")
    input.border:set_text(
      "top",
      " Prompt + " .. files_string .. " ",
      "center"
    )
  end
end

---@param selected_text string[] | nil
---@return { input_bufnr: integer, input_winid: integer, chat_bufnr: integer, chat_winid: integer }
function M.build_and_mount(selected_text)
  local chat = Popup(com.build_common_popup_opts("Chat w/ " .. Store.llm_provider .. "." .. Store.llm_model))
  local input = Popup(com.build_common_popup_opts("Prompt")) -- the Prompt part will be overwritten by calls to set_input_text

  -- available controls are found at the bottom of the input popup
  input.border:set_text(
    "bottom",
    " [S-]Tab cycle windows | C-j/k cycle models | C-c cancel request | C-n clear window | C-f add files | C-g clear files ",
    "center"
  )

  -- Register new right bufnr for backgrounded llm responses still running to write into
  Store.chat.chat.bufnr = chat.bufnr

  -- Input window is text with no syntax
  vim.api.nvim_buf_set_option(input.bufnr, 'filetype', 'txt')
  vim.api.nvim_buf_set_option(input.bufnr, 'syntax', '')

  -- Make input a 'scratch' buffer, effectively making it a temporary buffer
  vim.api.nvim_buf_set_option(input.bufnr, "buftype", "nofile")

  -- Chat in markdown
  vim.api.nvim_buf_set_option(chat.bufnr, 'filetype', 'markdown')

  vim.api.nvim_buf_set_keymap(
    input.bufnr,
    "n",
    "<CR>",
    "",
    { noremap = true, silent = true, callback = function() on_CR(input.bufnr, chat.bufnr, chat.winid) end }
  )

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
      Store.chat.input.clear()
      Store.chat.input.append(table.concat(input_lines, "\n"))
    end,
    { once = false }
  )

  layout:mount()

  -- Add text selection to input buf
  if selected_text then
    -- clear chat window
    vim.api.nvim_buf_set_lines(chat.bufnr, 0, -1, true, {})

    -- add selection to input
    vim.api.nvim_buf_set_lines(input.bufnr, 0, -1, true, selected_text)

    -- Go to bottom of input and enter insert mode
    local keys = vim.api.nvim_replace_termcodes('<Esc>Go', true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', true)
  else
    -- If there's saved input, render that
    local input_content = Store.chat.input.read()
    if input_content then com.safe_render_buffer_from_text(input.bufnr, input_content) end

    -- If there's a chat history, open with that.
    safe_render_buffer_from_messages(chat.bufnr, Store.chat.chat.read())

    -- Get the files back
    set_input_text(input)
  end

  -- keymaps
  local bufs = { chat.bufnr, input.bufnr }
  for i, buf in ipairs(bufs) do
    -- Tab cycles through windows
    vim.api.nvim_buf_set_keymap(buf, "n", "<Tab>", "", {
      noremap = true,
      silent = true,
      callback = function() on_tab(i, bufs) end,
    })

    -- Shift-Tab cycles through windows in reverse
    vim.api.nvim_buf_set_keymap(buf, "n", "<S-Tab>", "", {
      noremap = true,
      silent = true,
      callback = function() on_s_tab(i, bufs) end,
    })

    -- Ctl-n to reset session
    vim.api.nvim_buf_set_keymap(buf, "", "<C-n>", "", {
      noremap = true,
      silent = true,
      callback = function()
        Store.chat.clear()
        for _, bu in ipairs(bufs) do
          vim.api.nvim_buf_set_lines(bu, 0, -1, true, {})
        end
        set_input_text(input)
      end
    })

    -- Ctl-f to include files
    vim.api.nvim_buf_set_keymap(buf, "", "<C-f>", "", {
      noremap = true,
      silent = true,
      callback = function()
        local theme = require('telescope.themes').get_dropdown({ winblend = 10 })
        require('telescope.builtin').find_files(util.merge_tables(theme, {
          attach_mappings = function(_, map)
            map('i', '<CR>', function(prompt_bufnr)
              local selection = require('telescope.actions.state').get_selected_entry()
              Store.chat.append_file(selection[1])
              set_input_text(input)
              require('telescope.actions').close(prompt_bufnr)
            end)
            return true
          end
        }))
      end
    })

    -- Ctl-g to clear files
    vim.api.nvim_buf_set_keymap(buf, "", "<C-g>", "", {
      noremap = true,
      silent = true,
      callback = function()
        Store.chat.clear_files()
        set_input_text(input)
      end
    })

    -- Ctrl-c to kill active job
    vim.api.nvim_buf_set_keymap(buf, "", "<C-c>", "", {
      noremap = true,
      silent = true,
      callback = function()
        if Store.get_job() then
          Store.get_job().die()
        end
      end
    })

    -- Ctrl-j to cycle forward through llms
    vim.api.nvim_buf_set_keymap(buf, "", "<C-j>", "", {
      noremap = true,
      silent = true,
      callback = function()
        ---@type { model: string, provider: string }[]
        local model_options = {}

        for provider, models in pairs(Store.llm_models) do
          for _, model in ipairs(models) do
            table.insert(model_options, { provider = provider, model = model })
          end
        end

        local current_index = com.find_model_index(model_options)
        if not current_index then return end
        local selected_option = model_options[(current_index % #model_options) + 1]
        Store.set_llm(selected_option.provider, selected_option.model)
        chat.border:set_text("top", " Chat w/" .. com.model_display_name() .. " ", "center")
      end
    })

    -- Ctrl-k to cycle forward through llms
    vim.api.nvim_buf_set_keymap(buf, "", "<C-k>", "", {
      noremap = true,
      silent = true,
      callback = function()
        ---@type { model: string, provider: string }[]
        local model_options = {}

        for provider, models in pairs(Store.llm_models) do
          for _, model in ipairs(models) do
            table.insert(model_options, { provider = provider, model = model })
          end
        end

        local current_index = com.find_model_index(model_options)
        if not current_index then return end
        local selected_option = model_options[(current_index - 2) % #model_options + 1]
        Store.set_llm(selected_option.provider, selected_option.model)
        chat.border:set_text("top", " Chat w/" .. com.model_display_name() .. " ", "center")
      end
    })

    -- "q" exits from the thing
    -- TODO remove or test
    vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
      noremap = true,
      silent = true,
      callback = function() layout:unmount() end,
    })
  end

  return {
    input_bufnr = input.bufnr,
    input_winid = input.winid,
    chat_bufnr = chat.bufnr,
    chat_winid = chat.winid
  }
end

return M
