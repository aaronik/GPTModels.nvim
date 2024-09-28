local util   = require('gptmodels.util')
local com    = require('gptmodels.windows.common')
local Layout = require("nui.layout")
local Popup  = require("nui.popup")
local llm    = require('gptmodels.llm')
local Store  = require('gptmodels.store')

local M      = {}


-- The system prompt for the LLM
---@param filetype string
---@param input_text string
---@return string, string[]
local project_prompt = function(filetype, input_text)
  local prompt_string = [[
    \[USER REQUEST\]:
    %s
    \n\n
    \[FILE EXTENSION\]:
    %s
    \n\n
    \[INCLUDED FILES\]:
    \n\n
  ]]

  local prompt = string.format(prompt_string, input_text, filetype)

  local system_string = [[
    You are a high-quality software creation and modification system.
    The user will provide a request. The user may include files with the request, which will be below the request in the prompt.
    You produce code to accomplish the user's request.
    The code you produce must be in Unified Diff Format.
    The code may only apply to the files the user has included.
    An automated system will apply the diffs you provide, so please make sure the diffs are formatted correctly.

    Stylistic Notes:
    * The code you produce should be clean and avoid unnecessary complexity.
    * Any algorithms or complex operations in your code should have comments simplifying what's happening.
    * Any unusual parts of the code should have comments explaining why the code is there.
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


-- This function generates a layout of `num_boxes` boxes in a way that
-- hopefully allows for many readable boxes. It calculates the height of each
-- box as a percentage of the total available space, reuses existing popups
-- if possible to avoid memory leaks in NUI, and arranges them into columns
-- based on the total number of boxes.
---@param input NuiPopup
---@param num_boxes integer
---@param existing_pups NuiPopup[]
---@return NuiPopup[], NuiLayout.Box
local function build_layout_ui(input, num_boxes, existing_pups)
  local height = string.format("%.2f%%", 100 / (num_boxes > 5 and 5 or num_boxes))

  local boxes = {}
  local pups = {}
  for i = 1, num_boxes do
    -- reuse existing popups to avoid memory leak in nui
    ---@type NuiPopup
    local pup
    if i <= #existing_pups then
      pup = existing_pups[i]
    else
      pup = Popup(com.build_common_popup_opts("Project"))
    end
    table.insert(pups, pup)
    table.insert(boxes, Layout.Box(pup, { size = { width = "100%", height = height } }))
  end

  local column_size
  if num_boxes > 25 then
    column_size = { width = "17%" }
  elseif num_boxes > 20 then
    column_size = { width = "20%" }
  elseif num_boxes > 15 then
    column_size = { width = "25%" }
  elseif num_boxes > 10 then
    column_size = { width = "33.33%" }
  elseif num_boxes > 5 then
    column_size = { width = "50%" }
  else
    column_size = { width = "100%" }
  end

  local box_layout = {}
  local boxes_per_column = num_boxes > 5 and 5 or num_boxes

  for i = 1, math.ceil(num_boxes / boxes_per_column) do
    local start_index = (i - 1) * boxes_per_column + 1
    local end_index = math.min(i * boxes_per_column, num_boxes)
    local column_boxes = {}

    for j = start_index, end_index do
      table.insert(column_boxes, boxes[j])
    end

    table.insert(box_layout, Layout.Box(column_boxes, { dir = "col", size = column_size }))
  end

  return pups, Layout.Box({
    Layout.Box(box_layout, { dir = "row", size = "80%" }),
    Layout.Box(input, { size = "22%" }),
  }, { dir = "col" })
end


-- local function safe_render_right_text_from_store()
--   -- if the window is closed and reopened again while a response is streaming in,
--   -- right_bufnr will be wrong, and it won't get repopulated.
--   -- So we're assigning to ..right.bufnr every time the window opens.
--   local right_text = Store.code.right:read()
--   local bufnr = Store.code.right.popup.bufnr
--   if right_text and bufnr then
--     com.safe_render_buffer_from_text(Store.code.right.popup.bufnr, right_text)
--   end
-- end


-- -- Render the whole code window from the Store, respecting closed windows/buffers
-- local function safe_render_from_store()
--   local left_text = Store.code.left:read()
--   local left_buf = Store.code.left.popup.bufnr or -1
--   if left_text then com.safe_render_buffer_from_text(left_buf, left_text) end

--   local right_text = Store.code.right:read()
--   local right_buf = Store.code.right.popup.bufnr or -1
--   if right_text then com.safe_render_buffer_from_text(right_buf, right_text) end

--   local input_text = Store.code.input:read()
--   local input_buf = Store.code.input.popup.bufnr or -1
--   if input_text then com.safe_render_buffer_from_text(input_buf, input_text) end

--   -- Get the files back
--   com.set_input_top_border_text(Store.code.input.popup, Store.code:get_files())
-- end


---TODO Bring this to everyone
---Set all the keymaps that apply to all bufs; input and top bufs
---@param input NuiPopup
---@param bufs integer[]
local function set_common_keymaps(input, bufs)
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

    -- -- Ctl-n to reset session
    -- vim.api.nvim_buf_set_keymap(buf, "", "<C-n>", "", {
    --   noremap = true,
    --   silent = true,
    --   callback = function()
    --     Store.code:clear()
    --     for _, bu in ipairs(bufs) do
    --       vim.api.nvim_buf_set_lines(bu, 0, -1, true, {})
    --     end
    --     com.set_input_top_border_text(input, Store.code:get_files())
    --   end
    -- })

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
          -- com.set_window_title(top, com.model_display_name())
        end)
      end
    })

    -- Ctrl-j to cycle forward through llms
    vim.api.nvim_buf_set_keymap(buf, "", "<C-j>", "", {
      noremap = true,
      silent = true,
      callback = function()
        Store:cycle_model_forward()
        -- com.set_window_title(top, com.model_display_name())
      end
    })

    -- -- Ctrl-k to cycle forward through llms
    -- com.set_keymap(buf, "<C-k", function() Store:cycle_model_backward() end) -- TODO here and everywhere

    vim.api.nvim_buf_set_keymap(buf, "", "<C-k>", "", {
      noremap = true,
      silent = true,
      callback = function()
        Store:cycle_model_backward()
        -- com.set_window_title(top, com.model_display_name())
      end
    })

    -- Ctl-f to include files
    vim.api.nvim_buf_set_keymap(buf, "", "<C-f>", "", {
      noremap = true,
      silent = true,
      callback = com.launch_telescope_file_picker(function(filename)
        Store.project:append_file(filename)
        com.set_input_top_border_text(input, Store.project:get_files())
      end)
    })

    -- Ctl-g to clear files
    vim.api.nvim_buf_set_keymap(buf, "", "<C-g>", "", {
      noremap = true,
      silent = true,
      callback = function()
        Store.code:clear_files()
        -- com.set_input_top_border_text(input, Store.code:get_files())
      end
    })

    -- q to exit
    vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
      noremap = true,
      silent = true,
      callback = function()
        if Store.project.layout then Store.project.layout:unmount() end
      end,
    })
  end
end


---@param all_popups NuiPopup[]
local function set_common_settings(all_popups)
  -- Set buffers to same filetype as current file, for highlighting
  for _, pup in ipairs(all_popups) do
    vim.bo[pup.bufnr].filetype = vim.bo.filetype
    vim.wo[pup.winid].wrap = true
  end
end


-- turns one llm response string to lists of text lines
---@param text string
---@return string[][]
local function llm_text_to_chunk_lines(text)
  ---@type string[][]
  local chunk_lines = {}

  local chunks = vim.split(text, "```diff")

  for _, chunk in ipairs(chunks) do
    local lines = vim.split(chunk, "\n")
    table.insert(chunk_lines, lines)
  end

  util.log("chunk_lines:", chunk_lines)
  return chunk_lines
end


--- Take information (store state), render it, then return a bundle of view data
---@param input NuiPopup
---@param layout NuiLayout | nil
---@param previous_response_popups NuiPopup[]
---@param llm_text string
---@return NuiLayout, NuiPopup[]
local function render_project(input, layout, previous_response_popups, llm_text)
  local layout_config = {
    position = "50%",
    relative = "editor",
    size = {
      width = "90%",
      height = "90%",
    },
  }

  local llm_text_chunks = llm_text_to_chunk_lines(llm_text)

  local response_popups, layout_boxes = build_layout_ui(input, #llm_text_chunks, previous_response_popups)

  if not layout then
    layout = Layout(layout_config, layout_boxes)
  end

  layout:update(layout_boxes)
  layout:mount()
  vim.api.nvim_set_current_win(input.winid)

  -- Put llm response into popups
  for i, response_popup in ipairs(response_popups) do
    vim.api.nvim_buf_set_lines(response_popup.bufnr, 0, -1, true, llm_text_chunks[i])
  end

  return layout, response_popups
end


---@param input NuiPopup
---@param previous_response_popups NuiPopup[]
---@param layout NuiLayout
local on_CR = function(input, previous_response_popups, layout)
  -- TODO I don't like the assumption that there'll always be one here
  local top = previous_response_popups[1]
  local input_lines = vim.api.nvim_buf_get_lines(input.bufnr, 0, -1, false)
  local input_text = table.concat(input_lines, "\n")

  local filetype = vim.bo[top.bufnr].filetype

  local prompt, system = project_prompt(filetype, input_text)

  -- -- Clear the right window so the next response doesn't append to the previous one
  -- Store.code.right:clear()

  -- Loading indicator
  com.safe_render_buffer_from_text(top.bufnr, "Loading...")

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
        Store.project.response:append(err)
        -- safe_render_right_text_from_store()
        return
      end

      -- No response _and_ no error? Weird. Happens though.
      if not response then return end

      Store.project.response:append(response)

      -- safe_render_right_text_from_store()

      local layout, response_popups = render_project(input, layout, previous_response_popups, Store.project.response:read() or "")
      Store.project.layout = layout
      Store.project.response_popups = response_popups

      -- scroll to the bottom if the window's still open and the user is not in it
      -- (If they're in it, the priority is for them to be able to nav around and yank)
      -- com.safe_scroll_to_bottom_when_user_not_present(Store.code.right.popup.winid or 1, Store.code.right.popup.bufnr)
    end,
    on_end = function()
      Store:clear_job()
    end
  })

  Store:register_job(job)
end

---
---@param selection Selection | nil
---@return { input: NuiPopup, response_popups: NuiPopup[] }
function M.build_and_mount(selection)
  ---@type NuiPopup
  local top = Popup(com.build_common_popup_opts(com.model_display_name()))
  ---@type NuiPopup
  local input = Popup(com.build_common_popup_opts("Project"))

  -- Fetch all models so user can work with what they have on their system
  com.trigger_models_etl(function()
    -- all providers, but especially openai, can have the etl finish after a window has been closed, if it opens then closes real fast
    if top.bufnr and top.winid and vim.api.nvim_buf_is_valid(top.bufnr) and vim.api.nvim_win_is_valid(top.winid) then
      com.set_window_title(top, com.model_display_name())
    end
  end)

  --   -- When the user opened this from visual mode with text
  --   if selection then
  --     -- start by clearing all existing state
  --     Store.project.input:clear()
  --     -- Store.project.response_popups:clear()
  --     Store.project:clear_files()
  --     Store.project:clear()

  --     -- Put selection in input
  --     vim.api.nvim_buf_set_lines(input.bufnr, 0, -1, true, selection.lines)

  --     -- And into the store, so the next window open can have it
  --     Store.project.input:append(table.concat(selection.lines, "\n"))

  --     -- If selected lines are given, it's like a new session, so we'll nuke all else
  --     local extent_job = Store:get_job()
  --     if extent_job then
  --       extent_job.die()
  --       vim.wait(100, function() return extent_job.done() end)
  --     end
  --   else
  --     -- When the store already has some data
  --     -- If a selection is passed in, though, then it gets a new session
  --     safe_render_from_store()
  --   end

  -- First time rendering; don't yet have layout
  local layout, response_popups = render_project(input, nil, {top}, "")

  Store.project.response_popups = response_popups
  Store.project.layout          = layout

  local all_popups = util.merge_tables({ input }, response_popups)

  vim.api.nvim_buf_set_lines(response_popups[1].bufnr, 0, -1, true, { "fun", "lines", "wooo" })
  local ns_id = vim.api.nvim_create_namespace("")
  vim.api.nvim_buf_add_highlight(response_popups[1].bufnr, ns_id, "DiffAdd", 0, 0, 999)
  vim.api.nvim_buf_add_highlight(response_popups[1].bufnr, ns_id, "DiffDelete", 1, 0, 999)
  vim.api.nvim_buf_add_highlight(response_popups[1].bufnr, ns_id, "DiffChange", 2, 0, 999)
  -- vim.api.nvim_buf_clear_namespace(right.bufnr, ns_id, 0, -1)

  -- Turn off syntax highlighting for input buffer.
  vim.bo[input.bufnr].filetype = "txt"
  vim.bo[input.bufnr].syntax = ""

  -- Make input a 'scratch' buffer, effectively making it a temporary buffer
  vim.bo[input.bufnr].buftype = "nofile"

  -- recalculate nui window when vim window resizes
  input:on("VimResized", function()
    if Store.project.layout then Store.project.layout:update() end
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
        on_CR(input, response_popups, layout)
      end
    }
  )

  -- Further Keymaps
  ---@type integer[]
  local bufs = vim.tbl_map(function(popup) return popup.bufnr end, all_popups)
  set_common_keymaps(input, bufs)
  set_common_settings(all_popups)

  -- Notify of any errors / warnings
  for level, message in pairs(com.check_deps()) do
    if message then
      vim.notify_once(message, vim.log.levels[level])
    end
  end

  return {
    input = input,
    response_popups = response_popups
  }
end

return M
