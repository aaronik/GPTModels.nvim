local M = {}

M.INCLUDED_FILE_PREFIX = "[INCLUDED FILE]"

---build full file include prompt, meant to be in one message
---@param file_name string
---@param file_content string
function M.included_file(file_name, file_content)
  return M.INCLUDED_FILE_PREFIX .. "\n* file name: " .. file_name .. "\n* file content: \n\n" .. file_content
end

return M
