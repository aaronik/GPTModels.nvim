local util = require('../lua.util')

local Layout = require("nui.layout")
local Popup = require("nui.popup")

local M = {}

-- -- This works to close the popup. Probably good to delete the buffer too!
-- local function close_popup(bufnr)
--   vim.api.nvim_buf_delete(bufnr, { force = true })
-- end

function _GPTOnEditWindowCR(input_bufnr, code_bufnr)
  util.log('TODO Submit the coooooooooode')
  local input_text = vim.api.nvim_buf_get_lines(input_bufnr, 0, -1, false)
  local code_text = vim.api.nvim_buf_get_lines(code_bufnr, 0, -1, false)
  util.log(input_text)
  util.log(code_text)
  -- close_popup(input_bufnr) -- This 'accidentally' closes all windows, which is the behavior i want
end

local function build_common_popup_opts(text)
  return {
    border = {
      style = "rounded",
      text = {
        top = " " .. text .. " ",
        top_align = "center",
        bottom = "",
        bottom_align = "center",
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

function M.build_and_mount(selected_text)
  local top_left_popup = Popup(build_common_popup_opts("Left"))
  local top_right_popup = Popup(build_common_popup_opts("Right"))
  local input = Popup(build_common_popup_opts("Multiline Input"))

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

  if selected_text then
    vim.api.nvim_buf_set_lines(top_left_popup.bufnr, 0, -1, true, selected_text)
  end

  -- -- Close the popup when leaving the buffer, just nice to have
  -- -- local event = require("nui.utils.autocmd").event
  -- input:on(event.BufLeave, function()
  --   close_popup(input.bufnr)
  -- end, { once = true })

  -- -- When <CR> is pressed in normal mode within this popup, we call our handler function
  -- popup:on(event.TextChangedI, function(opts)
  --   -- unfortunately opts does not contain the key code. If it did, we could use this rather than the hacky keymap below
  --   util.log(opts)
  -- end)

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
