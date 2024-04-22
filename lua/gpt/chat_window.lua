local util = require('gpt.util')
  local event = require("nui.utils.autocmd").event

local Layout = require("nui.layout")
local Popup = require("nui.popup")

local M = {}

-- This works to close the popup. Probably good to delete the buffer too!
local function close_popup(bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })
end

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

function M.build_and_mount()
  local top_popup = Popup(build_common_popup_opts("Chat"))
  local input = Popup(build_common_popup_opts("Prompt"))

  -- Experimenting with md
  vim.api.nvim_buf_set_option(input.bufnr, 'filetype', 'md')

  -- Make input a 'scratch' buffer, effectively making it a temporary buffer
  vim.api.nvim_buf_set_option(input.bufnr, "buftype", "nofile")

  -- Set buffers to same filetype as current file, for highlighting
  vim.api.nvim_buf_set_option(top_popup.bufnr, 'filetype', vim.bo.filetype)

  -- Close the popup when leaving the buffer, just nice to have
  input:on(event.BufLeave, function()
    close_popup(input.bufnr)
  end, { once = true })

  -- TODO The goal is to call a function when <CR> is pressed in normal mode within this popup.
  -- This way works, but it's gross. I'd much rather something like popup:on(<CR>, whatever()),
  -- and run lua code from there. Don't want to convert everything to strings to pass it.
  vim.api.nvim_buf_set_keymap(
    input.bufnr,
    "n",
    "<CR>",
    ":lua _GPTOnEditWindowCR(" .. input.bufnr .. ", " .. top_popup.bufnr .. ")<CR>",
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
        Layout.Box(top_popup, { size = "100%" }),
      }, { dir = "row", size = "80%" }),
      Layout.Box(input, { size = "22%" }),
    }, { dir = "col" })
  )

  layout:mount()
end

return M

