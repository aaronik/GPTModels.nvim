local M = {}

---@type string
M.LLM_DECODE_ERROR_STRING = " [JSON decode or schema error for LLM response]: "

M.DIAGNOSTIC_SEVERITY_LABEL_MAP = {
  [1] = "ERROR",
  [2] = "WARN",
  [3] = "INFO",
  [4] = "HINT",
}

return M
