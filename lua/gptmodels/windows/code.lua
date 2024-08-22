local util        = require('gptmodels.util')
local com         = require('gptmodels.windows.common')
local Layout      = require("nui.layout")
local Popup       = require("nui.popup")
local llm         = require('gptmodels.llm')
local Store       = require('gptmodels.store')

local M           = {}

-- The system prompt for the LLM
---@param filetype string
---@param input_text string
---@param code_text string
---@return string, string[]
local code_prompt = function(filetype, input_text, code_text)
  local prompt_string = [[
    \[USER INPUT\]:
    %s
    \n\n
    \[FILE EXTENSION\]:
    %s
    \n\n
    \[INCLUDED CODE\]:
    %s
    \n\n
    \[INCLUDED FILES\]:
    \n\n
  ]]

  local prompt = string.format(prompt_string, input_text, filetype, code_text)

  local system_string = [[
    You are a high-quality software creation and modification system.
    Your code should be clean and avoid unnecessary complexity.
    Include comments for any tricky or unusual parts of the code to explain what they are and why they are there.
    Your task is to assist with the included code and the user's request.
    The user may include reference files for context.
    Only provide code and comments in your response, as it goes directly into a code viewing window.
    Do not include any explanations or descriptions.
    Do not wrap the code in triple backticks.
  ]]

  local system = { system_string }

  for _, filename in ipairs(Store.code:get_files()) do
    local file = io.open(filename, "r")
    if not file then break end
    local content = file:read("*all")
    file:close()

    prompt = prompt .. filename .. ":\n\n" .. content .. "\n\n---\n\n"
  end

  return prompt, system
end

local function safe_render_right_text_from_store()
  -- if the window is closed and reopened again while a response is streaming in,
  -- right_bufnr will be wrong, and it won't get repopulated.
  -- So we're assigning to ..right.bufnr every time the window opens.
  local right_text = Store.code.right:read()
  local bufnr = Store.code.right.popup.bufnr
  if right_text and bufnr then
    com.safe_render_buffer_from_text(Store.code.right.popup.bufnr, right_text)
  end
end

-- Render the whole code window from the Store, respecting closed windows/buffers
local function safe_render_from_store()
  local left_text = Store.code.left:read()
  local left_buf = Store.code.left.popup.bufnr or -1
  if left_text then com.safe_render_buffer_from_text(left_buf, left_text) end

  local right_text = Store.code.right:read()
  local right_buf = Store.code.right.popup.bufnr or -1
  if right_text then com.safe_render_buffer_from_text(right_buf, right_text) end

  local input_text = Store.code.input:read()
  local input_buf = Store.code.input.popup.bufnr or -1
  if input_text then com.safe_render_buffer_from_text(input_buf, input_text) end

  -- Get the files back
  com.set_input_top_border_text(Store.code.input.popup, Store.code:get_files())
end

local on_CR = function(input_bufnr, left_bufnr, right_bufnr)
  local input_lines = vim.api.nvim_buf_get_lines(input_bufnr, 0, -1, false)
  local input_text = table.concat(input_lines, "\n")
  local left_lines = vim.api.nvim_buf_get_lines(left_bufnr, 0, -1, false)
  local left_text = table.concat(left_lines, "\n")

  local filetype = vim.bo[left_bufnr].filetype

  local prompt, system = code_prompt(filetype, input_text, left_text)

  -- Clear the right window so the next response doesn't append to the previous one
  Store.code.right:clear()

  -- Loading indicator
  com.safe_render_buffer_from_text(right_bufnr, "Loading...")

  -- Nuke existing jobs
  if Store:get_job() then
    Store:get_job().die()
  end

  local job = llm.generate({
    llm = {
      stream = true,
      prompt = prompt,
      system = system,
    },
    on_read = function(err, response)
      if err then
        Store.code.right:append(err)
        safe_render_right_text_from_store()
        return
      end

      -- No response _and_ no error? Weird. Happens though.
      if not response then return end

      Store.code.right:append(response)

      safe_render_right_text_from_store()

      -- scroll to the bottom if the window's still open and the user is not in it
      -- (If they're in it, the priority is for them to be able to nav around and yank)
      com.safe_scroll_to_bottom_when_user_not_present(Store.code.right.popup.winid or 1, Store.code.right.popup.bufnr)
    end,
    on_end = function()
      Store:clear_job()
    end
  })

  Store:register_job(job)
end

---@param selection Selection | nil
---@return { input: NuiPopup, right: NuiPopup, left: NuiPopup }
function M.build_and_mount(selection)
  ---@type NuiPopup
  local left = Popup(com.build_common_popup_opts("On Deck"))
  ---@type NuiPopup
  local right = Popup(com.build_common_popup_opts(com.model_display_name()))
  ---@type NuiPopup
  local input = Popup(com.build_common_popup_opts("Prompt"))

  com.set_input_bottom_border_text(input, { "C-x xfer to deck" })

  -- Register popups with store
  Store.code.right.popup = right
  Store.code.left.popup = left
  Store.code.input.popup = input

  -- Fetch ollama models so user can work with what they have on their system
  com.trigger_ollama_models_etl(function()
    com.set_window_title(right, com.model_display_name())
  end)

  -- Turn off syntax highlighting for input buffer.
  vim.bo[input.bufnr].filetype = "txt"
  vim.bo[input.bufnr].syntax = ""

  -- Make input a 'scratch' buffer, effectively making it a temporary buffer
  vim.bo[input.bufnr].buftype = "nofile"

  -- Set buffers to same filetype as current file, for highlighting
  vim.bo[left.bufnr].filetype = vim.bo.filetype
  vim.bo[right.bufnr].filetype = vim.bo.filetype

  -- When the user opened this from visual mode with text
  if selection then
    -- start by clearing all existing state
    Store.code.input:clear()
    Store.code.left:clear()
    Store.code.right:clear()
    Store.code:clear_files()

    -- Put diagnostics fix string into the input window
    local diagnostics = vim.diagnostic.get(0)
    local relevant_diagnostics, relevant_diagnostic_count = util.get_relevant_diagnostics(diagnostics, selection)

    if relevant_diagnostic_count > 0 then
      vim.api.nvim_buf_set_lines(input.bufnr, 0, -1, true, relevant_diagnostics)
      for _, line in ipairs(relevant_diagnostics) do
        Store.code.input:append(line .. '\n')
      end
    end

    -- Put selection in left pane
    vim.api.nvim_buf_set_lines(left.bufnr, 0, -1, true, selection.lines)

    -- And into the store, so the next window open can have it
    Store.code.left:append(table.concat(selection.lines, "\n"))

    -- If selected lines are given, it's like a new session, so we'll nuke all else
    local extent_job = Store:get_job()
    if extent_job then
      extent_job.die()
      vim.wait(100, function() return extent_job.done() end)
    end
  else
    -- When the store already has some data
    -- If a selection is passed in, though, then it gets a new session
    safe_render_from_store()
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
      Layout.Box({
        Layout.Box(left, { size = "50%" }),
        Layout.Box(right, { size = "50%" }),
      }, { dir = "row", size = "80%" }),
      Layout.Box(input, { size = "20%" }),
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
      Store.code.input:clear()
      Store.code.input:append(table.concat(input_lines, "\n"))
    end
  )

  -- For input, set <CR>
  vim.api.nvim_buf_set_keymap(input.bufnr, "n", "<CR>", "",
    {
      noremap = true,
      silent = true,
      callback = function()
        on_CR(input.bufnr, left.bufnr, right.bufnr)
      end
    }
  )

  -- Further Keymaps
  local bufs = { left.bufnr, right.bufnr, input.bufnr }
  for i, buf in ipairs(bufs) do
    -- Tab cycles through windows
    vim.api.nvim_buf_set_keymap(buf, "n", "<Tab>", "", {
      noremap = true,
      silent = true,
      callback = function()
        com.cycle_tabs_forward(i, bufs)
      end
    })

    -- Shift-Tab cycles through windows in reverse
    vim.api.nvim_buf_set_keymap(buf, "n", "<S-Tab>", "", {
      noremap = true,
      silent = true,
      callback = function()
        com.cycle_tabs_backward(i, bufs)
      end
    })

    -- Ctl-n to reset session
    vim.api.nvim_buf_set_keymap(buf, "", "<C-n>", "", {
      noremap = true,
      silent = true,
      callback = function()
        Store.code:clear()
        for _, bu in ipairs(bufs) do
          vim.api.nvim_buf_set_lines(bu, 0, -1, true, {})
        end
        com.set_input_top_border_text(input, Store.code:get_files())
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

    -- Ctrl-p to open model picker
    vim.api.nvim_buf_set_keymap(buf, "", "<C-p>", "", {
      noremap = true,
      silent = true,
      callback = function()
        com.launch_telescope_model_picker(function()
          com.set_window_title(right, com.model_display_name())
        end)
      end
    })

    -- Ctrl-j to cycle forward through llms
    vim.api.nvim_buf_set_keymap(buf, "", "<C-j>", "", {
      noremap = true,
      silent = true,
      callback = function()
        Store:cycle_model_forward()
        com.set_window_title(right, com.model_display_name())
      end
    })

    -- Ctrl-k to cycle forward through llms
    vim.api.nvim_buf_set_keymap(buf, "", "<C-k>", "", {
      noremap = true,
      silent = true,
      callback = function()
        Store:cycle_model_backward()
        com.set_window_title(right, com.model_display_name())
      end
    })

    -- Ctl-f to include files
    vim.api.nvim_buf_set_keymap(buf, "", "<C-f>", "", {
      noremap = true,
      silent = true,
      callback = com.launch_telescope_file_picker(function(filename)
        Store.code:append_file(filename)
        com.set_input_top_border_text(input, Store.code:get_files())
      end)
    })

    -- Ctl-g to clear files
    vim.api.nvim_buf_set_keymap(buf, "", "<C-g>", "", {
      noremap = true,
      silent = true,
      callback = function()
        Store.code:clear_files()
        com.set_input_top_border_text(input, Store.code:get_files())
      end
    })

    -- Ctl-x to clear files
    vim.api.nvim_buf_set_keymap(buf, "", "<C-x>", "", {
      noremap = true,
      silent = true,
      callback = function()
        local right_text = Store.code.right:read()
        if not right_text then return end
        Store.code.left:clear()
        Store.code.left:append(right_text)
        Store.code.right:clear()
        com.safe_render_buffer_from_text(right.bufnr, Store.code.right:read() or "")
        com.safe_render_buffer_from_text(left.bufnr, Store.code.left:read() or "")
      end
    })

    -- q to exit
    vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
      noremap = true,
      silent = true,
      callback = function()
        layout:unmount()
      end,
    })
  end

  -- Once this mounts, our popups now have a winid for as long as the layout is mounted
  layout:mount()

  -- Wrap lines, because these are small windows and it's nicer
  vim.wo[left.winid].wrap = true
  vim.wo[right.winid].wrap = true
  vim.wo[input.winid].wrap = true

  -- Notify of any errors / warnings
  for level, message in pairs(com.check_deps()) do
    if message then
      vim.notify_once(message, vim.log.levels[level])
    end
  end

  return {
    input = input,
    right = right,
    left = left
  }
end

return M
