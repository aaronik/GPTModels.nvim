local M = {}

function M.build_common_popup_opts(text)
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

-- This works to close the popup. Probably good to delete the buffer too!
function M.close_popup(bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })
end

return M

-- Some memories, since I'm so new at this

-- -- Close the popup when leaving the buffer, just nice to have
-- input:on(event.BufLeave, function()
--   com.close_popup(input.bufnr)
-- end, { once = true })

