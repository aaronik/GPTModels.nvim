---@diagnostic disable: undefined-global

local util = require("gpt.util")
local assert = require("luassert")
local gpt = require('gpt')
local edit_window = require('gpt.edit_window')
local chat_window = require('gpt.chat_window')

function CommonBefore()
  before_each(function()
    -- Set current window dims, otherwise it defaults to 0 and nui.layout complains about not having a pos integer height
    vim.api.nvim_win_set_height(0, 100)
    vim.api.nvim_win_set_width(0, 100)

    -- clear cmd history, lest it get remembered and bleed across tests
    vim.fn.histdel('cmd')
  end)
end

describe("gpt.run (the main function)", function()
  CommonBefore()

  it("opens in visual mode without error", function()
    gpt.run({ visual_mode = true })
  end)

  it("opens in normal mode without error", function()
    gpt.run({ visual_mode = false })
  end)
end)

describe("gpt.edit_window", function()
  CommonBefore()

  it("has no error with text", function()
    edit_window.build_and_mount({ "text line 1", "text line 2" })
  end)

  it("has no error without text", function()
    edit_window.build_and_mount()
  end)

  it("returns buffer numbers", function()
    local bufs = edit_window.build_and_mount()
    assert.is_not(bufs.input_bufnr, nil)
    assert.is_not(bufs.left_bufnr, nil)
    assert.is_not(bufs.right_bufnr, nil)
  end)

  it("shifts through windows on <Tab>", function()
    local bufs = edit_window.build_and_mount()
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

  it("opens in input mode", function()
    edit_window.build_and_mount()
    vim.api.nvim_feedkeys('xhello', 'mtx', true)
    -- For some reason, the first letter is always trimmed off. But if it's not in insert mode, the line will be empty ""
    assert.same(vim.api.nvim_get_current_line(), 'hello')
  end)

  it("doesn't error on <CR>", function()
    edit_window.build_and_mount()
    local keys = vim.api.nvim_replace_termcodes('ihello<Esc><CR>', true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', false)
  end)
end)

describe("gpt.chat_window", function()
  CommonBefore()

  it("returns buffer numbers", function()
    local bufs = chat_window.build_and_mount()
    assert.is_not(bufs.input_bufnr, nil)
    assert.is_not(bufs.chat_bufnr, nil)
  end)

  it("opens in input mode", function()
    chat_window.build_and_mount()
    vim.api.nvim_feedkeys('xhello', 'mtx', true)
    -- For some reason, the first letter is always trimmed off. But if it's not in insert mode, the line will be empty ""
    assert.same(vim.api.nvim_get_current_line(), 'hello')
  end)

  it("puts text in chat window on <CR> and removes it from input window", function()
    local bufs = chat_window.build_and_mount()
    local input_bufnr = bufs.input_bufnr
    local chat_bufnr = bufs.chat_bufnr

    local keys = vim.api.nvim_replace_termcodes('ihello<Esc><CR>', true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', false)

    local chat_text = vim.api.nvim_buf_get_text(chat_bufnr, 0, 0, -1, -1, {})

    -- ensure hello is one of the lines in chat buf
    local contains_hello = false
    for _, line in ipairs(chat_text) do
      if line == "hello" then
        contains_hello = true
        break
      end
    end
    assert.is_true(contains_hello)

    -- ensure input is empty
    local input_text = vim.api.nvim_buf_get_text(input_bufnr, 0, 0, -1, -1, {})
    contains_hello = false
    for _, line in ipairs(input_text) do
      if line == "hello" then
        contains_hello = true
        break
      end
    end
    assert.is_not_true(contains_hello)
  end)
end)
