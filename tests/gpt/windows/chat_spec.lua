---@diagnostic disable: undefined-global

-- TODO use telescope to add files to chat! This could be a defining feature.

require('gpt.types')
local util = require("gpt.util")
local assert = require("luassert")
local chat_window = require('gpt.windows.chat')
local stub = require('luassert.stub')
local llm = require('gpt.llm')

describe("The Chat window", function()
  before_each(function()
    -- Set current window dims, otherwise it defaults to 0 and nui.layout complains about not having a pos integer height
    vim.api.nvim_win_set_height(0, 100)
    vim.api.nvim_win_set_width(0, 100)

    -- clear cmd history, lest it get remembered and bleed across tests
    vim.fn.histdel('cmd')

    -- stubbing job:new prevents the llm call from happening
    -- TODO Add llm layer, which switches over adapters based on config,
    -- and can be stubbed itself
    local job = require('plenary.job')
    local s = stub(job, "new")
    s.returns({ start = function() end })
  end)

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

  it("shifts through windows on <Tab>", function()
    local bufs = chat_window.build_and_mount()
    local input_bufnr = bufs.input_bufnr
    local chat_bufnr = bufs.chat_bufnr

    local input_win = vim.fn.bufwinid(input_bufnr)
    local chat_win = vim.fn.bufwinid(chat_bufnr)

    local esc = vim.api.nvim_replace_termcodes('<Esc>', true, true, true)
    local tab = vim.api.nvim_replace_termcodes("<Tab>", true, true, true)

    vim.api.nvim_feedkeys(esc, 'mtx', true)
    assert.equal(vim.api.nvim_get_current_win(), input_win)
    vim.api.nvim_feedkeys(tab, 'mtx', true)
    assert.equal(vim.api.nvim_get_current_win(), chat_win)
    vim.api.nvim_feedkeys(tab, 'mtx', true)
    assert.equal(vim.api.nvim_get_current_win(), input_win)
  end)

  it("shifts through windows on <S-Tab>", function()
    local bufs = chat_window.build_and_mount()
    local input_bufnr = bufs.input_bufnr
    local chat_bufnr = bufs.chat_bufnr

    local input_win = vim.fn.bufwinid(input_bufnr)
    local chat_win = vim.fn.bufwinid(chat_bufnr)

    local esc = vim.api.nvim_replace_termcodes('<Esc>', true, true, true)
    local tab = vim.api.nvim_replace_termcodes("<S-Tab>", true, true, true)

    vim.api.nvim_feedkeys(esc, 'mtx', true)
    assert.equal(vim.api.nvim_get_current_win(), input_win)
    vim.api.nvim_feedkeys(tab, 'mtx', true)
    assert.equal(vim.api.nvim_get_current_win(), chat_win)
    vim.api.nvim_feedkeys(tab, 'mtx', true)
    assert.equal(vim.api.nvim_get_current_win(), input_win)
  end)

  it("On <CR> removes text from input and puts it in chat", function()
    local bufs = chat_window.build_and_mount()
    local input_bufnr = bufs.input_bufnr
    local chat_bufnr = bufs.chat_bufnr

    local keys = vim.api.nvim_replace_termcodes('xhello<Esc><CR>', true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', false)

    local chat_lines = vim.api.nvim_buf_get_lines(chat_bufnr, 0, -1, true)

    -- ensure hello is one of the lines in chat buf
    local contains_hello = false
    for _, line in ipairs(chat_lines) do
      if line == "hello" then
        contains_hello = true
        break
      end
    end
    assert.is_true(contains_hello)

    -- ensure input is empty
    local input_lines = vim.api.nvim_buf_get_lines(input_bufnr, 0, -1, true)
    assert.same(input_lines, { "" })
  end)

  it("On <CR> it places the llm response into chat", function()
    local bufs = chat_window.build_and_mount()
    local input_bufnr = bufs.input_bufnr
    local chat_bufnr = bufs.chat_bufnr

    -- stub llm call
    local s = stub(llm, "make_request")

    -- make call to llm stub
    local keys = vim.api.nvim_replace_termcodes('xhello<Esc><CR>', true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', false)

    -- grab the given callback
    local on_response = s.calls[1].refs[1].on_response
    local on_end = s.calls[1].refs[1].on_end

    -- simulate llm responding
    on_response("response text1\nresponse text2")
    on_end()

    local chat_lines = vim.api.nvim_buf_get_lines(chat_bufnr, 0, -1, true)

    local contains_hello = false
    local contains_1 = false
    local contains_2 = false
    for _, line in ipairs(chat_lines) do
      if line == "hello" then contains_hello = true end
      if line == "response text1" then contains_1 = true end
      if line == "response text2" then contains_2 = true end
    end
    assert.is_true(contains_hello)
    assert.is_true(contains_1)
    assert.is_true(contains_2)
  end)

  it("Gives the entire contents of the chat to the LLM", function()
    local bufs = chat_window.build_and_mount()
    local input_bufnr = bufs.input_bufnr
    local chat_bufnr = bufs.chat_bufnr

    -- stub llm call
    local s = stub(llm, "make_request")

    -- add some text to input buffer
    vim.api.nvim_buf_set_lines(input_bufnr, 0, -1, true, { "user input 1" })

    -- press enter
    local keys = vim.api.nvim_replace_termcodes('<CR>', true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', false)

    -- grab the given prompt
    ---@type MakeGenerateRequestArgs
    local args = s.calls[1].refs[1]

    -- https://github.com/ollama/ollama/blob/main/docs/api.md#request-8
    local messages = args.messages

    P(s.calls[1].refs[1].messages)

    -- TODO Loop it
    assert.equal(messages[1].role, "user")
    assert.equal(messages[1].content, "user input 1")
    assert.equal(messages[2].role, "assistant")
    assert.equal(messages[2].content, "assistant input 1")
    assert.equal(messages[3].role, "user")
    assert.equal(messages[3].content, "user input 2")
    assert.equal(messages[4].role, "assistant")
    assert.equal(messages[4].content, "assistant input 2")
  end)
end)
