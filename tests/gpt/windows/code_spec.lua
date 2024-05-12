---@diagnostic disable: undefined-global

local util = require("gpt.util")
local assert = require("luassert")
local code_window = require('gpt.windows.code')
local stub = require('luassert.stub')
local llm = require('gpt.llm')
local cmd = require('gpt.cmd')
local Store = require('gpt.store')

describe("The code window", function()
  before_each(function()
    -- Set current window dims, otherwise it defaults to 0 and nui.layout complains about not having a pos integer height
    vim.api.nvim_win_set_height(0, 100)
    vim.api.nvim_win_set_width(0, 100)

    stub(cmd, "exec")

    Store.clear()
  end)

  it("returns buffer numbers, winids", function()
    local code = code_window.build_and_mount()
    assert.is_not.equal(code.input_bufnr, nil)
    assert.is_not.equal(code.right_bufnr, nil)
    assert.is_not.equal(code.left_bufnr, nil)
    assert.is_not.equal(code.input_winid, nil)
    assert.is_not.equal(code.right_winid, nil)
    assert.is_not.equal(code.left_winid, nil)
  end)

  it("places given provided text in left window", function()
    local given_lines = { "text line 1", "text line 2" }
    local chat = code_window.build_and_mount(given_lines)
    local gotten_lines = vim.api.nvim_buf_get_lines(chat.left_bufnr, 0, -1, true)
    assert.same(given_lines, gotten_lines)
  end)

  it("shifts through windows on <Tab>", function()
    local chat = code_window.build_and_mount()
    local input_bufnr = chat.input_bufnr
    local left_bufnr = chat.left_bufnr
    local right_bufnr = chat.right_bufnr

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
    local chat = code_window.build_and_mount()
    local input_bufnr = chat.input_bufnr
    local left_bufnr = chat.left_bufnr
    local right_bufnr = chat.right_bufnr

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
    local chat = code_window.build_and_mount()

    local s = stub(llm, "generate")

    local keys = vim.api.nvim_replace_termcodes('xhello<Esc><CR>', true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', false)

    ---@type MakeGenerateRequestArgs
    local args = s.calls[1].refs[1]

    -- simulate a multiline resposne from the llm
    args.on_read(nil, "line 1\nline 2")

    -- Those lines should be separated on newlines and placed into the right buf
    assert.same(vim.api.nvim_buf_get_lines(chat.right_bufnr, 0, -1, true), { "line 1", "line 2" })
  end)

  it("includes a system prompt", function()
    code_window.build_and_mount()
    local s = stub(llm, "generate")

    -- Make a request to start a job
    local keys = vim.api.nvim_replace_termcodes('xincluding system prompt?<Esc><CR>', true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', false)

    ---@type MakeGenerateRequestArgs
    local args = s.calls[1].refs[1]
    assert.is_not.same(args.llm.system, nil)
  end)

  it("includes file type", function()
    -- return "lua" for filetype request
    stub(vim.api, "nvim_buf_get_option").returns("lua")

    code_window.build_and_mount()
    local s = stub(llm, "generate")

    -- Make a request to start a job
    local keys = vim.api.nvim_replace_termcodes('xincluding filetype?<Esc><CR>', true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', false)

    ---@type MakeGenerateRequestArgs
    local args = s.calls[1].refs[1]

    assert.not_same(string.find(args.llm.prompt, "lua"), nil)
    assert.is_not.same(args.llm.prompt, nil)
  end)

  it("Has a loading indicator", function()
    local chat = code_window.build_and_mount()

    local s = stub(llm, "generate")

    local keys = vim.api.nvim_replace_termcodes('xloading test<Esc><CR>', true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', false)

    ---@type MakeGenerateRequestArgs
    local args = s.calls[1].refs[1]

    -- before on_response gets a response from the llm, the right window should show a loading indicator
    assert.same(vim.api.nvim_buf_get_lines(chat.right_bufnr, 0, -1, true), { "Loading..." })

    -- simulate a response from the llm
    args.on_read(nil, "response line")

    -- After the response, the loading indicator should be replaced by the response
    assert.same(vim.api.nvim_buf_get_lines(chat.right_bufnr, 0, -1, true), { "response line" })
  end)

  it("finishes jobs in the background when closed", function()
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

    -- quit with :q
    keys = vim.api.nvim_replace_termcodes('<Esc>:q<CR>', true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', false)

    -- -- quit with q
    -- keys = vim.api.nvim_replace_termcodes('q', true, true, true)
    -- vim.api.nvim_feedkeys(keys, 'mtx', false)

    assert.is_not.True(die_called)

    -- -- simulate hint of wait time for the nui windows to close
    -- -- TODO This leads to errors about invalid windows. Gotta fix
    -- vim.wait(10)

    ---@type MakeGenerateRequestArgs
    local args = s.calls[1].refs[1]

    args.on_read(nil, "response to be saved in background")

    -- Open up and ensure it's there now
    local chat = code_window.build_and_mount()
    assert.same({ "response to be saved in background" }, vim.api.nvim_buf_get_lines(chat.right_bufnr, 0, -1, true))

    -- More reponse to still reopen window
    args.on_read(nil, "\nadditional response")

    -- Gets that response without reopening
    local right_lines = vim.api.nvim_buf_get_lines(chat.right_bufnr, 0, -1, true)
    assert.same({ "response to be saved in background", "additional response" }, right_lines)
  end)


  it("opens prepopulated w/ prior session when no text provided", function()
    Store.code.right.append("right content")
    Store.code.input.append("input content")
    Store.code.left.append("left content")

    local chat = code_window.build_and_mount()

    local right_lines = vim.api.nvim_buf_get_lines(chat.right_bufnr, 0, -1, true)
    local input_lines = vim.api.nvim_buf_get_lines(chat.input_bufnr, 0, -1, true)
    local left_lines = vim.api.nvim_buf_get_lines(chat.left_bufnr, 0, -1, true)

    assert.same({ "right content" }, right_lines)
    assert.same({ "input content" }, input_lines)
    assert.same({ "left content" }, left_lines)
  end)

  it("does not open prepopulated w/ prior session when text is provided", function()
    Store.code.right.append("right content")
    Store.code.input.append("input content")
    Store.code.left.append("left content")

    local chat = code_window.build_and_mount({ "provided text" })

    local right_lines = vim.api.nvim_buf_get_lines(chat.right_bufnr, 0, -1, true)
    local input_lines = vim.api.nvim_buf_get_lines(chat.input_bufnr, 0, -1, true)
    local left_lines = vim.api.nvim_buf_get_lines(chat.left_bufnr, 0, -1, true)

    assert.same({ "" }, right_lines)
    assert.same({ "" }, input_lines)
    assert.same({ "provided text" }, left_lines)
  end)

  it("Replaces prior llm response with new one", function()
    local chat = code_window.build_and_mount()

    local s = stub(llm, "generate")

    -- Input anything
    local keys = vim.api.nvim_replace_termcodes('xtesting first response<Esc><CR>', true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', false)

    ---@type MakeGenerateRequestArgs
    local args_first = s.calls[1].refs[1]

    -- Simulate first response
    args_first.on_read(nil, "first response line")
    if args_first.on_end then args_first.on_end() end

    -- Response is shown
    assert.same(vim.api.nvim_buf_get_lines(chat.right_bufnr, 0, -1, true), { "first response line" })

    -- Input whatever
    keys = vim.api.nvim_replace_termcodes('xtesting second response<Esc><CR>', true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', false)
    if args_first.on_end then args_first.on_end() end

    ---@type MakeGenerateRequestArgs
    local args_second = s.calls[2].refs[1]

    -- Simulate second response
    args_second.on_read(nil, "second response line")

    -- Second response replaced first response
    assert.same(vim.api.nvim_buf_get_lines(chat.right_bufnr, 0, -1, true), { "second response line" })
  end)

  it("clears all windows on <C-n>", function()
    local chat = code_window.build_and_mount()

    -- Populate windows with some content
    vim.api.nvim_buf_set_lines(chat.input_bufnr, 0, -1, true, { "input content" })
    vim.api.nvim_buf_set_lines(chat.left_bufnr, 0, -1, true, { "left content" })
    vim.api.nvim_buf_set_lines(chat.right_bufnr, 0, -1, true, { "right content" })

    -- Press <C-n>
    local keys = vim.api.nvim_replace_termcodes("<C-n>", true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', true)

    -- Assert all windows are cleared
    assert.same({ '' }, vim.api.nvim_buf_get_lines(chat.input_bufnr, 0, -1, true))
    assert.same({ '' }, vim.api.nvim_buf_get_lines(chat.left_bufnr, 0, -1, true))
    assert.same({ '' }, vim.api.nvim_buf_get_lines(chat.right_bufnr, 0, -1, true))
  end)

  it("kills active job on <C-c>", function()
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

    -- press ctrl-n
    keys = vim.api.nvim_replace_termcodes('<C-c>', true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', false)

    assert.is_true(die_called)
  end)

  it("saves input text on InsertLeave and prepopulates on reopen", function()
    local initial_input = "some initial input"
    local chat = code_window.build_and_mount()

    -- Populate input window with some content and enter normal mode
    vim.api.nvim_buf_set_lines(chat.input_bufnr, 0, -1, true, { initial_input })

    -- Enter insert mode
    local keys = vim.api.nvim_replace_termcodes("i", true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', true)

    -- <Esc> to trigger save
    keys = vim.api.nvim_replace_termcodes("<Esc>", true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', true)

    -- Close the window with :q
    keys = vim.api.nvim_replace_termcodes(":q<CR>", true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', true)

    -- Reopen the window
    chat = code_window.build_and_mount()

    local input_lines = vim.api.nvim_buf_get_lines(chat.input_bufnr, 0, -1, true)

    assert.same({ initial_input }, input_lines)
  end)

  it("saves state of all three windows and prepopulates them on reopen", function()
    local llm_stub = stub(llm, "generate")

    -- left window is saved when it opens
    local chat = code_window.build_and_mount({ "left" })

    -- Add user input
    vim.api.nvim_buf_set_lines(chat.input_bufnr, 0, -1, true, { "input" })

    -- Enter insert mode, so we can leave it
    local keys = vim.api.nvim_replace_termcodes("i", true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', true)

    -- <Esc> triggers save
    keys = vim.api.nvim_replace_termcodes("<Esc>", true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', true)

    -- <CR> triggers llm call
    keys = vim.api.nvim_replace_termcodes("<CR>", true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', true)

    -- right window is saved when an llm response comes in
    ---@type MakeGenerateRequestArgs
    local args = llm_stub.calls[1].refs[1]
    args.on_read(nil, "right")

    -- Close the window with :q
    keys = vim.api.nvim_replace_termcodes(":q<CR>", true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', true)

    -- Reopen the window
    chat = code_window.build_and_mount()

    local input_lines = vim.api.nvim_buf_get_lines(chat.input_bufnr, 0, -1, true)
    local left_lines = vim.api.nvim_buf_get_lines(chat.left_bufnr, 0, -1, true)
    local right_lines = vim.api.nvim_buf_get_lines(chat.right_bufnr, 0, -1, true)

    assert.same({ "input" }, input_lines)
    assert.same({ "left" }, left_lines)
    assert.same({ "right" }, right_lines)
  end)

  -- TODO Test this more thoroughly.
  -- * Put both in describe
  -- * before each mocking of all providers, same as in llm_spec
  -- * send request, assert provider from store is hit
  -- * Press <C-j>
  -- * assert store has changed provider
  -- * send new request, assert new provider from store is hit
  it("cycles through available models with <C-j>", function()
    code_window.build_and_mount()

    local store_stub = stub(Store, 'set_llm')

    -- Press <C-j>
    local keys = vim.api.nvim_replace_termcodes("<C-j>", true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', true)

    assert.stub(store_stub).was_called(1)
    local args = store_stub.calls[1].refs
    assert.equal(type(args[1]), "string")
    assert.equal(type(args[2]), "string")
  end)

  pending("cycles through available models with <C-k>", function()
    code_window.build_and_mount()

    local store_stub = stub(Store, 'set_llm')

    -- Press <C-j>
    local keys = vim.api.nvim_replace_termcodes("<C-k>", true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', true)

    assert.stub(store_stub).was_called(1)
    local args = store_stub.calls[1].refs
    assert.equal(type(args[1]), "string")
    assert.equal(type(args[2]), "string")
  end)

  it("puts json decoding errors in the right window as [ERROR] inline with what it was writing", function()

  end)


end)
