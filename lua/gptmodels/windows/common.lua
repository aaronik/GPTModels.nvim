local Store = require('gptmodels.store')
local cmd = require('gptmodels.cmd')
local util = require('gptmodels.util')
local ollama = require('gptmodels.providers.ollama')

local M = {}

---@param title string
function M.build_common_popup_opts(title)
  ---@type nui_popup_options
  return {
    border = {
      style = "rounded",
      text = {
        top = " " .. title .. " ",
        top_align = "center",
        bottom = "",
        bottom_align = "right",
      },
    },
    focusable = true,
    enter = true,
    win_options = {
      -- winhighlight = "Normal:Normal",
      winhighlight = "Normal:Normal,FloatBorder:SpecialChar",
    },
  }
end

-- This works to close the popup. Probably good to delete the buffer too!
function M.close_popup(bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })
end

function M.model_display_name()
  local model_info = Store:get_model()
  return model_info.provider .. "." .. model_info.model
end

-- Render text to a buffer _if the buffer is still valid_,
-- so this is safe to call on potentially closed buffers.
---@param bufnr integer
---@param text string
function M.safe_render_buffer_from_text(bufnr, text)
  if not bufnr then return end
  -- local buf_loaded = vim.api.nvim_buf_is_loaded(bufnr)
  local buf_loaded = true
  local buf_valid = vim.api.nvim_buf_is_valid(bufnr)

  if not (buf_loaded and buf_valid) then return end

  local buf_writable = vim.bo[bufnr].modifiable
  if not buf_writable then return end

  local response_lines = vim.split(text or "", "\n")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, response_lines)
end

-- Render text to a buffer _if the buffer is still valid_,
-- so this is safe to call on potentially closed buffers.
---@param bufnr integer
---@param lines string[]
function M.safe_render_buffer_from_lines(bufnr, lines)
  if not bufnr then return end
  local buf_loaded = vim.api.nvim_buf_is_loaded(bufnr)
  local buf_valid = vim.api.nvim_buf_is_valid(bufnr)
  if not (buf_loaded and buf_valid) then return end

  local buf_writable = vim.bo[bufnr].modifiable
  if not buf_writable then return end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
end

-- Check for required programs, warn user if they're not there
---@return string | nil
function M.check_deps()
  local failed = false
  local return_string = [[
Error - missing required dependencies.
GPTModels.nvim requires the following programs installed, which are not detected in your path:
  ]]

  for _, prog in ipairs({ "ollama", "curl" }) do
    cmd.exec({
      sync = true,
      cmd = "which",
      args = { prog },
      onexit = function(code)
        if code ~= 0 then
          return_string = return_string .. prog .. " "
          failed = true
        end
      end
    })
  end

  if failed then
    return return_string
  else
    return nil
  end
end

-- Scroll to the bottom of a given window/buffer pair.
-- Checks window validity and ensures user is not in the window before attempting scroll.
---@param winid integer
---@param bufnr integer
M.safe_scroll_to_bottom_when_user_not_present = function(winid, bufnr)
  if vim.api.nvim_win_is_valid(winid) and vim.api.nvim_get_current_win() ~= winid then
    vim.api.nvim_win_set_cursor(
      winid, { vim.api.nvim_buf_line_count(bufnr), 0 }
    )
  end
end

-- available controls are found at the bottom of the input popup
---@param input NuiPopup
---@param extra_commands? table<string>
M.set_input_bottom_border_text = function(input, extra_commands)
  local commands = {
    "q quit",
    "[S]Tab cycle windows",
    "C-c cancel request",
    "C-j/k/p cycle/pick models",
    "C-n clear all",
    "C-f/g add/clear files",
  }

  if extra_commands ~= nil then
    commands = util.merge_tables(commands, extra_commands)
  end

  local commands_str = " " .. table.concat(commands, " | ") .. " "
  input.border:set_text("bottom", commands_str, "center")
end

---@param input NuiPopup
---@param files table<string>
M.set_input_top_border_text = function(input, files)
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

---@param win_index integer
---@param bufs table<integer>
M.cycle_tabs_forward = function(win_index, bufs)
  local next_buf_index = (win_index % #bufs) + 1
  local next_win = vim.fn.bufwinid(bufs[next_buf_index])
  vim.api.nvim_set_current_win(next_win)
end

---@param win_index integer
---@param bufs table<integer>
M.cycle_tabs_backward = function(win_index, bufs)
  local prev_buf_index = (win_index - 2) % #bufs + 1
  local prev_win = vim.fn.bufwinid(bufs[prev_buf_index])
  vim.api.nvim_set_current_win(prev_win)
end

---@param popup NuiPopup
---@param title string
M.set_window_title = function(popup, title)
  popup.border:set_text("top", " " .. title .. " ", "center")
end

-- Triggers the fetching / saving of available models from the ollama server
---@param on_complete fun(): nil
M.trigger_ollama_models_etl = function(on_complete)
  ollama.fetch_models(function(err, ollama_models)
    -- TODO If there's an issue fetching, I want to display that to the user.
    if err then return util.log(err) end
    if not ollama_models or #ollama_models == 0 then return end
    Store:set_models("ollama", ollama_models)
    on_complete()
  end)
end

-- Generates a function that abstracts the telescope stuff, w/ a simpler api
---@param on_complete fun(filename: string): nil
M.launch_telescope_file_picker = function(on_complete)
  return function()
    local theme = require('telescope.themes').get_dropdown({ winblend = 10 })
    require('telescope.builtin').find_files(util.merge_tables(theme, {
      prompt_title = "include file name/contents in prompt",
      attach_mappings = function(_, map)
        map('i', '<CR>', function(prompt_bufnr)
          local selection = require('telescope.actions.state').get_selected_entry()
          on_complete(selection[1])
          require('telescope.actions').close(prompt_bufnr)
        end)
        return true
      end
    }))
  end
end

-- Generates a function that abstracts the telescope stuff, w/ a simpler api
---@param on_complete fun(): nil
M.launch_telescope_model_picker = function(on_complete)
  local theme = require('telescope.themes').get_dropdown({ winblend = 10 })
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local state = require('telescope.actions.state')
  local pickers = require('telescope.pickers')

  local opts = util.merge_tables(theme, {
    attach_mappings = function(_, map)
      map('i', '<CR>', function(bufnr)
        local selection = state.get_selected_entry()
        local model_split = vim.split(selection[1], ".", { plain = true })
        local provider = model_split[1]
        local model = table.concat(model_split, ".", 2)
        if not (provider and model) then return end
        Store:set_model(provider, model)
        on_complete()
        actions.close(bufnr)
      end)
      return true
    end
  })

  pickers.new(opts, {
    prompt_title = "pick a model",
    finder = require('telescope.finders').new_table {
      results = Store:llm_model_strings()
    },
    sorter = conf.generic_sorter({}),
  }):find()
end

return M
