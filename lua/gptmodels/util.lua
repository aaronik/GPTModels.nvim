local constants = require "gptmodels.constants"

-- Utility functions
local M = {}

-- remove program code from lua cache, reload
M.RELOAD = function(...)
  return require("plenary.reload").reload_module(...)
end

-- modified 'require'; use to flush entire program from top level for plugin development.
M.R = function(name)
  M.RELOAD(name)
  return require(name)
end

-- print tables contents
M.P = function(v)
  print(vim.inspect(v))
  return v
end

-- Log to the file debug.log in the root. File can be watched for easier debugging.
M.log = function(...)
  local args = { ... }

  -- Canonical log dir
  local data_path = vim.fn.stdpath("data") .. "/gptmodels"

  -- If no dir on fs, make it
  if vim.fn.isdirectory(data_path) == 0 then
    vim.fn.mkdir(data_path, "p")
  end

  local log_file = io.open(data_path .. "/debug.log", "a")

  -- Guard against no log file by making one
  if not log_file then
    log_file = io.open(data_path .. "/debug.log", "w+")
  end

  -- Swallow further errors
  -- This is a utility for development, it should never cause issues
  -- during real use.
  if not log_file then return end

  -- Write each arg to disk
  for _, arg in ipairs(args) do
    if type(arg) == "table" then
      arg = vim.inspect(arg)
    end

    log_file:write(tostring(arg) .. "\n")
  end

  log_file:flush() -- Ensure the output is written immediately
  log_file:close()
end

---@param lines string[]
---@param string string
M.contains_line = function(lines, string)
  local found_line = false
  for _, line in ipairs(lines) do
    if line == string then
      found_line = true
      break
    end
  end
  return found_line
end

--- Merging multiple tables into one. Works on both map like and array like tables.
--- This function accepts variadic arguments (multiple tables)
--- It merges keys from the provided tables into a new table.
--- @generic T
--- @param ... T - Any number of tables to merge.
--- @return T - A new merged table of the same type as the input tables.
M.merge_tables = function(...)
  local new_table = {}

  for _, t in ipairs({...}) do
    for k, v in pairs(t) do
      if type(k) == "number" then
        table.insert(new_table, v)
      else
        new_table[k] = v
      end
    end
  end

  return new_table
end

M.guid = function()
  local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
  return string.gsub(template, '[xy]', function(c)
    local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
    return string.format('%x', v)
  end)
end

---Get useful data about the current visual selection
---@return Selection
M.get_visual_selection = function()
  local start_line = vim.fn.getpos("'<")[2] - 1
  local end_line = vim.fn.getpos("'>")[2] - 1
  local start_column = vim.fn.getpos("'<")[3] - 1
  local end_column = vim.fn.getpos("'>")[3]

  local end_col = math.min(end_column, 2147483646)
  local lines = vim.api.nvim_buf_get_text(
    0, start_line, start_column, end_line, end_col, {}
  )

  ---@type Selection
  local selection = {
    start_line = start_line,
    end_line = end_line,
    start_column = start_column,
    end_column = end_column,
    lines = lines
  }

  return selection
end

---@param env_key string
---@return boolean
M.has_env_var = function(env_key)
  return type(os.getenv(env_key)) ~= type(nil)
end

-- Get the messages from diagnostics that are present between start_line and end_line, inclusive
---@param diagnostics vim.Diagnostic[]
---@param selection Selection
---@return string[], integer
M.get_relevant_diagnostics = function(diagnostics, selection)
  local relevant_diagnostics = {}
  local count = 0
  for _, diagnostic in ipairs(diagnostics) do
    if diagnostic.lnum >= selection.start_line and diagnostic.lnum <= selection.end_line then
      local selection_problem_code_start_line = diagnostic.lnum - selection.start_line + 1
      local selection_problem_code_end_line = diagnostic.end_lnum - selection.start_line + 1
      local problem_code_lines = { unpack(selection.lines, selection_problem_code_start_line, selection_problem_code_end_line) }

      local severity_label = constants.DIAGNOSTIC_SEVERITY_LABEL_MAP[diagnostic.severity]

      count = count + 1

      local split_diagnostic_message = vim.split(diagnostic.message, "\n")
      relevant_diagnostics = M.merge_tables(
        relevant_diagnostics,
        { "", "[LINE(S)]" },
        problem_code_lines,
        { "[" .. severity_label .. "]" },
        split_diagnostic_message
      )
    end
  end

  table.insert(relevant_diagnostics, 1, "Please fix the following " .. count .. " LSP Diagnostic(s) in this code:")

  return relevant_diagnostics, count
end

return M
