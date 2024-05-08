---@diagnostic disable: undefined-global

local util = require("gpt.util")
local assert = require("luassert")
local code_window = require('gpt.windows.code')
local stub = require('luassert.stub')
local llm = require('gpt.llm')
local cmd = require('gpt.cmd')
local Store = require('gpt.store')

describe("The Code window", function()
  before_each(function()
    -- Set current window dims, otherwise it defaults to 0 and nui.layout complains about not having a pos integer height
    vim.api.nvim_win_set_height(0, 100)
    vim.api.nvim_win_set_width(0, 100)

    stub(cmd, "exec")

    Store.clear()
  end)

  it("returns buffer numbers", function()
    local bufs = code_window.build_and_mount()
    assert.is_not(bufs.input_bufnr, nil)
    assert.is_not(bufs.left_bufnr, nil)
    assert.is_not(bufs.right_bufnr, nil)
  end)

  it("opens in input mode", function()
    code_window.build_and_mount()
    vim.api.nvim_feedkeys('xhello', 'mtx', true)
    -- For some reason, the first letter is always trimmed off. But if it's not in insert mode, the line will be empty ""
    assert.same(vim.api.nvim_get_current_line(), 'hello')
  end)

  it("opens with recent usage with no text provided", function()
    Store.code.right.append("right content")
    Store.code.input.append("input content")
    Store.code.left.append("left content")

    local bufs = code_window.build_and_mount()

    local right_lines = vim.api.nvim_buf_get_lines(bufs.right_bufnr, 0, -1, true)
    local input_lines = vim.api.nvim_buf_get_lines(bufs.input_bufnr, 0, -1, true)
    local left_lines = vim.api.nvim_buf_get_lines(bufs.left_bufnr, 0, -1, true)

    assert.same({ "right content" }, right_lines)
    assert.same({ "input content" }, input_lines)
    assert.same({ "left content" }, left_lines)
  end)

  it("does not open with recent usage when text is provided", function()
    Store.code.right.append("right content")
    Store.code.input.append("input content")
    Store.code.left.append("left content")

    local bufs = code_window.build_and_mount({ "provided text" })

    local right_lines = vim.api.nvim_buf_get_lines(bufs.right_bufnr, 0, -1, true)
    local input_lines = vim.api.nvim_buf_get_lines(bufs.input_bufnr, 0, -1, true)
    local left_lines = vim.api.nvim_buf_get_lines(bufs.left_bufnr, 0, -1, true)

    assert.same({ "" }, right_lines)
    assert.same({ "" }, input_lines)
    assert.same({ "provided text" }, left_lines)
  end)

  it("places given selected text in left window", function()
    local given_lines = { "text line 1", "text line 2" }
    local bufs = code_window.build_and_mount(given_lines)
    local gotten_lines = vim.api.nvim_buf_get_lines(bufs.left_bufnr, 0, -1, true)
    assert.same(given_lines, gotten_lines)
  end)

  it("shifts through windows on <Tab>", function()
    local bufs = code_window.build_and_mount()
    local input_bufnr = bufs.input_bufnr
    local left_bufnr = bufs.left_bufnr
    local right_bufnr = bufs.right_bufnr

    local input_win = vim.fn.bufwinid(input_bufnr)
    local left_win = vim.fn.bufwinid(left_bufnr)
    local right_win = vim.fn.bufwinid(right_bufnr)

    local esc = vim.api.nvim_replace_termcodes('<Esc>', true, true, true)
    local tab = vim.api.nvim_replace_termcodes("<Tab>", true, true, true)

    vim.api.nvim_feedkeys(esc, 'mtx', true)
    assert.equal(vim.api.nvim_get_current_win(), input_win)
    vim.api.nvim_feedkeys(tab, 'mtx', true)
    assert.equal(vim.api.nvim_get_current_win(), left_win)
    vim.api.nvim_feedkeys(tab, 'mtx', true)
    assert.equal(vim.api.nvim_get_current_win(), right_win)
    vim.api.nvim_feedkeys(tab, 'mtx', true)
    assert.equal(vim.api.nvim_get_current_win(), input_win)
  end)

  it("shifts through windows on <S-Tab>", function()
    local bufs = code_window.build_and_mount()
    local input_bufnr = bufs.input_bufnr
    local left_bufnr = bufs.left_bufnr
    local right_bufnr = bufs.right_bufnr

    local input_win = vim.fn.bufwinid(input_bufnr)
    local left_win = vim.fn.bufwinid(left_bufnr)
    local right_win = vim.fn.bufwinid(right_bufnr)

    local esc = vim.api.nvim_replace_termcodes('<Esc>', true, true, true)
    local tab = vim.api.nvim_replace_termcodes("<S-Tab>", true, true, true)

    vim.api.nvim_feedkeys(esc, 'mtx', true)
    assert.equal(vim.api.nvim_get_current_win(), input_win)
    vim.api.nvim_feedkeys(tab, 'mtx', true)
    assert.equal(vim.api.nvim_get_current_win(), right_win)
    vim.api.nvim_feedkeys(tab, 'mtx', true)
    assert.equal(vim.api.nvim_get_current_win(), left_win)
    vim.api.nvim_feedkeys(tab, 'mtx', true)
    assert.equal(vim.api.nvim_get_current_win(), input_win)
  end)

  it("Places llm responses into right window", function()
    local bufs = code_window.build_and_mount()

    local s = stub(llm, "generate")

    local keys = vim.api.nvim_replace_termcodes('xhello<Esc><CR>', true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', false)

    ---@type MakeGenerateRequestArgs
    local args = s.calls[1].refs[1]

    -- before on_response gets a response from the llm, the right window should be empty
    assert.same(vim.api.nvim_buf_get_lines(bufs.right_bufnr, 0, -1, true), { "" })

    -- simulate a multiline resposne from the llm
    args.on_read(nil, "line 1\nline 2")

    -- Those lines should be separated on newlines and placed into the right buf
    assert.same(vim.api.nvim_buf_get_lines(bufs.right_bufnr, 0, -1, true), { "line 1", "line 2" })
  end)

  it("includes a system prompt", function()
    code_window.build_and_mount()
    local s = stub(llm, "generate")

    -- Make a request to start a job
    local keys = vim.api.nvim_replace_termcodes('xincluding system prompt?<Esc><CR>', true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', false)

    local args = s.calls[1].refs[1]

    assert.is_not.same(args.llm.system, nil)
  end)

  -- TODO Actually, maybe we don't want to kill the job? Maybe it should just continue to
  -- run and populate a store in the background?
  it("kills jobs and closes the window when q is pressed", function()
    code_window.build_and_mount()
    local s = stub(llm, "generate")
    local die_called = false

    s.returns({
      die = function()
        die_called = true
      end
    })

    -- Make a request to start a job
    local keys = vim.api.nvim_replace_termcodes('xhello<Esc><CR>', true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', false)

    -- press q
    keys = vim.api.nvim_replace_termcodes('q', true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', false)

    assert.is_true(die_called)
  end)
end)
