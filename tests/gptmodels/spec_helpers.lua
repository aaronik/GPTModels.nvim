local M = {}

---@param lines string[]
---@return Selection
M.build_selection = function(lines)
  return {
    start_line = 0,
    end_line = 0,
    start_column = 0,
    end_column = 0,
    text = lines
  }
end

M.diagnostic_response = { {
  bufnr = 73,
  code = "exp-in-action",
  col = 4,
  end_col = 31,
  end_lnum = 803,
  lnum = 803,
  message = "Unexpected <exp> .",
  namespace = 34,
  severity = 1,
  source = "Lua Syntax Check.",
  user_data = {
    lsp = {
      code = "exp-in-action",
      data = "syntax"
    }
  }
}, {
  _tags = {
    unnecessary = true
  },
  bufnr = 73,
  code = "unused-local",
  col = 6,
  end_col = 10,
  end_lnum = 0,
  lnum = 0,
  message = "Unused local `what`.",
  namespace = 34,
  severity = 4,
  source = "Lua Diagnostics.",
  user_data = {
    lsp = {
      code = "unused-local"
    }
  }
}, {
  _tags = {
    unnecessary = true
  },
  bufnr = 73,
  code = "unused-local",
  col = 6,
  end_col = 9,
  end_lnum = 1,
  lnum = 1,
  message = "Unused local `bob`.",
  namespace = 34,
  severity = 4,
  source = "Lua Diagnostics.",
  user_data = {
    lsp = {
      code = "unused-local"
    }
  }
}, {
  _tags = {
    unnecessary = true
  },
  bufnr = 73,
  code = "unused-local",
  col = 10,
  end_col = 14,
  end_lnum = 805,
  lnum = 805,
  message = "Unused local `code`.",
  namespace = 34,
  severity = 4,
  source = "Lua Diagnostics.",
  user_data = {
    lsp = {
      code = "unused-local"
    }
  }
} }

return M
