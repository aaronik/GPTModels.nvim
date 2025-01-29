---@diagnostic disable: undefined-global

local util        = require("gptmodels.util")
local assert      = require("luassert")
local code_window = require('gptmodels.windows.code')
local stub        = require('luassert.stub')
local llm         = require('gptmodels.llm')
local Store       = require('gptmodels.store')
local helpers     = require('tests.gptmodels.spec_helpers')

describe("The code window", function()
  helpers.hook_reset_state()
  helpers.hook_seed_store()

  it("places provided selected text in left window", function()
    local given_lines = { "text line 1", "text line 2" }
    local code = code_window.build_and_mount(helpers.generate_selection(given_lines))
    local gotten_lines = vim.api.nvim_buf_get_lines(code.left.bufnr, 0, -1, true)
    assert.same(given_lines, gotten_lines)
  end)

  it("clears all windows, kills job, and clears files when opened with selected text", function()
    -- First, open a window and add some stuff
    local first_given_lines = { "first" }
    code_window.build_and_mount(helpers.generate_selection(first_given_lines)) -- populate left pane

    local die_called = false

    local llm_stub = stub(llm, "generate")
    llm_stub.returns({
      die = function()
        die_called = true
      end,
      done = function()
        return die_called
      end
    })

    -- Send a request
    local keys = vim.api.nvim_replace_termcodes('xhello<Esc><CR>', true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', false) -- populate input, fire request

    ---@type MakeGenerateRequestArgs
    local args = llm_stub.calls[1].refs[1]

    args.on_read(nil, "some content") -- populate right pane

    -- add files
    Store.code:append_file("README.md")

    -- close the window
    keys = vim.api.nvim_replace_termcodes(':q<CR>', true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', false) -- populate input, fire request

    local second_given_lines = { "second" }

    -- reopen window with new selection
    local code = code_window.build_and_mount(helpers.generate_selection(second_given_lines))

    -- old job got killed
    assert(die_called)

    -- all panes got cleared, left has new selection
    local left_lines = vim.api.nvim_buf_get_lines(code.left.bufnr, 0, -1, true)
    local right_lines = vim.api.nvim_buf_get_lines(code.right.bufnr, 0, -1, true)
    local input_lines = vim.api.nvim_buf_get_lines(code.input.bufnr, 0, -1, true)
    assert.same(second_given_lines, left_lines)
    assert.same({ "" }, right_lines)
    assert.same({ "" }, input_lines)

    -- files were removed
    assert.same({}, Store.code:get_filenames())
  end)

  it("shifts through windows on <Tab>", function()
    local code = code_window.build_and_mount()
    local input_bufnr = code.input.bufnr
    local left_bufnr = code.left.bufnr
    local right_bufnr = code.right.bufnr

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
    local code = code_window.build_and_mount()
    local input_bufnr = code.input.bufnr
    local left_bufnr = code.left.bufnr
    local right_bufnr = code.right.bufnr

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
    local code = code_window.build_and_mount()

    local generate_stub = stub(llm, "generate")

    local keys = vim.api.nvim_replace_termcodes('xhello<Esc><CR>', true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', false)

    ---@type MakeGenerateRequestArgs
    local args = generate_stub.calls[1].refs[1]

    -- simulate a multiline resposne from the llm
    args.on_read(nil, "line 1\nline 2")

    -- Those lines should be separated on newlines and placed into the right buf
    assert.same(vim.api.nvim_buf_get_lines(code.right.bufnr, 0, -1, true), { "line 1", "line 2" })
  end)

  it("includes a system prompt", function()
    code_window.build_and_mount()
    local generate_stub = stub(llm, "generate")

    -- Make a request to start a job
    local keys = vim.api.nvim_replace_termcodes('xincluding system prompt?<Esc><CR>', true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', false)

    ---@type MakeGenerateRequestArgs
    local args = generate_stub.calls[1].refs[1]
    assert.is_not.same(args.llm.system, nil)
  end)

  it("includes file type", function()
    local bufnr = vim.api.nvim_get_current_buf()
    vim.bo[bufnr].filetype = "lua"
    code_window.build_and_mount()

    local generate_stub = stub(llm, "generate")

    -- Make a request to start a job
    local keys = vim.api.nvim_replace_termcodes('xincluding filetype?<Esc><CR>', true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', false)

    ---@type MakeGenerateRequestArgs
    local args = generate_stub.calls[1].refs[1]

    assert.not_nil(string.find(args.llm.prompt, "lua"))
    assert.not_nil(args.llm.prompt)
  end)

  it("Has a loading indicator", function()
    local code = code_window.build_and_mount()

    local generate_stub = stub(llm, "generate")

    local keys = vim.api.nvim_replace_termcodes('xloading test<Esc><CR>', true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', false)

    ---@type MakeGenerateRequestArgs
    local args = generate_stub.calls[1].refs[1]

    -- before on_response gets a response from the llm, the right window should show a loading indicator
    assert.same(vim.api.nvim_buf_get_lines(code.right.bufnr, 0, -1, true), { "Loading..." })

    -- simulate a response from the llm
    args.on_read(nil, "response line")

    -- After the response, the loading indicator should be replaced by the response
    assert.same(vim.api.nvim_buf_get_lines(code.right.bufnr, 0, -1, true), { "response line" })
  end)

  it("does not open prepopulated w/ prior session when text is provided", function()
    Store.code.right:append("right content")
    Store.code.input:append("input content")
    Store.code.left:append("left content")

    local code = code_window.build_and_mount(helpers.generate_selection({ "provided text" }))

    local right_lines = vim.api.nvim_buf_get_lines(code.right.bufnr, 0, -1, true)
    local input_lines = vim.api.nvim_buf_get_lines(code.input.bufnr, 0, -1, true)
    local left_lines = vim.api.nvim_buf_get_lines(code.left.bufnr, 0, -1, true)

    assert.same({ "" }, right_lines)
    assert.same({ "" }, input_lines)
    assert.same({ "provided text" }, left_lines)
  end)

  it("Replaces prior llm response with new one", function()
    local code = code_window.build_and_mount()

    local generate_stub = stub(llm, "generate")

    -- Input anything
    local keys = vim.api.nvim_replace_termcodes('xtesting first response<Esc><CR>', true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', false)

    ---@type MakeGenerateRequestArgs
    local args_first = generate_stub.calls[1].refs[1]

    -- Simulate first response
    args_first.on_read(nil, "first response line")
    if args_first.on_end then args_first.on_end() end

    -- Response is shown
    assert.same(vim.api.nvim_buf_get_lines(code.right.bufnr, 0, -1, true), { "first response line" })

    -- Input whatever
    keys = vim.api.nvim_replace_termcodes('xtesting second response<Esc><CR>', true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', false)
    if args_first.on_end then args_first.on_end() end

    ---@type MakeGenerateRequestArgs
    local args_second = generate_stub.calls[2].refs[1]

    -- Simulate second response
    args_second.on_read(nil, "second response line")

    -- Second response replaced first response
    assert.same(vim.api.nvim_buf_get_lines(code.right.bufnr, 0, -1, true), { "second response line" })
  end)

  it("clears all windows on <C-n>", function()
    local code = code_window.build_and_mount()

    -- Populate windows with some content
    vim.api.nvim_buf_set_lines(code.input.bufnr, 0, -1, true, { "input content" })
    vim.api.nvim_buf_set_lines(code.left.bufnr, 0, -1, true, { "left content" })
    vim.api.nvim_buf_set_lines(code.right.bufnr, 0, -1, true, { "right content" })
    Store.code:append_file("docs/gpt.txt")

    -- Press <C-n>
    local keys = vim.api.nvim_replace_termcodes("<C-n>", true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', true)

    -- Assert all windows are cleared
    assert.same({ '' }, vim.api.nvim_buf_get_lines(code.input.bufnr, 0, -1, true))
    assert.same({ '' }, vim.api.nvim_buf_get_lines(code.left.bufnr, 0, -1, true))
    assert.same({ '' }, vim.api.nvim_buf_get_lines(code.right.bufnr, 0, -1, true))

    -- And the store of included files
    assert.same({}, Store.code:get_filenames())
  end)

  it("transfers contents of right pane to left pane on <C-x> (xfer)", function()
    local code = code_window.build_and_mount()

    local generate_stub = stub(llm, "generate")

    -- Send a request
    local init_keys = vim.api.nvim_replace_termcodes("itransfer panes<Esc><CR>", true, true, true)
    vim.api.nvim_feedkeys(init_keys, 'mtx', true)

    ---@type MakeGenerateRequestArgs
    local args = generate_stub.calls[1].refs[1]

    -- Get some stuff into the right pane, this will get transfered around
    args.on_read(nil, "xfer")

    -- It's in the right pane, see?
    assert.same({ "xfer" }, vim.api.nvim_buf_get_lines(code.right.bufnr, 0, -1, true))

    -- Send a request
    local xfer_keys = vim.api.nvim_replace_termcodes("<C-x>", true, true, true)
    vim.api.nvim_feedkeys(xfer_keys, 'mtx', true)

    -- Now it's in the left pane
    assert.same({ "xfer" }, vim.api.nvim_buf_get_lines(code.left.bufnr, 0, -1, true))

    -- And not in the right pane
    assert.same({ "" }, vim.api.nvim_buf_get_lines(code.right.bufnr, 0, -1, true))
  end)

  it("saves state of all three windows and prepopulates them on reopen", function()
    local llm_stub = stub(llm, "generate")

    -- left window is saved when it opens
    local code = code_window.build_and_mount(helpers.generate_selection({ "left" }))

    -- Add user input
    vim.api.nvim_buf_set_lines(code.input.bufnr, 0, -1, true, { "input" })

    -- Enter insert mode, so we can leave it
    helpers.feed_keys("i")

    -- <Esc> triggers save
    helpers.feed_keys("<Esc>")

    -- <CR> triggers llm call
    helpers.feed_keys("<CR>")

    -- right window is saved when an llm response comes in
    ---@type MakeGenerateRequestArgs
    local args = llm_stub.calls[1].refs[1]
    args.on_read(nil, "right")

    -- Close the window with :q
    helpers.feed_keys(":q<CR>")

    -- Reopen the window
    code = code_window.build_and_mount()

    local input_lines = vim.api.nvim_buf_get_lines(code.input.bufnr, 0, -1, true)
    local left_lines = vim.api.nvim_buf_get_lines(code.left.bufnr, 0, -1, true)
    local right_lines = vim.api.nvim_buf_get_lines(code.right.bufnr, 0, -1, true)

    assert.same({ "input" }, input_lines)
    assert.same({ "left" }, left_lines)
    assert.same({ "right" }, right_lines)
  end)

  it("includes LSP diagnostics when present within selection", function()
    ---@type Selection
    local selection = {
      start_line = 1,
      end_line = 2,
      start_column = 0,
      end_column = 10,
      lines = { "code_with_problem()", "code_without_problem()" }
    }

    -- make sure start/end lines contain the correct two diagnostics from helpers.diagnostic_response
    local diagnostics = {
      { severity = 1, lnum = 1, end_lnum = 1, message = "Error on line 1\n  Second line of message" },
      { severity = 1, lnum = 2, end_lnum = 2, message = "Warning on line 2" },
      { severity = 1, lnum = 3, end_lnum = 3, message = "Note on line 3" },
    }

    local get_diagnostic_stub = stub(vim.diagnostic, 'get')
    get_diagnostic_stub.returns(diagnostics)

    local code = code_window.build_and_mount(selection)

    local input_lines = vim.api.nvim_buf_get_lines(code.input.bufnr, 0, -1, true)
    assert.stub(get_diagnostic_stub).was_called(1)
    assert(util.contains_line(input_lines, "Please fix the following 2 LSP Diagnostic(s) in this code:"))

    -- close window
    local keys = vim.api.nvim_replace_termcodes(':q<CR>', true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', false)

    -- reopen
    code = code_window.build_and_mount()

    -- lines should remain in input window
    input_lines = vim.api.nvim_buf_get_lines(code.input.bufnr, 0, -1, true)
    assert(util.contains_line(input_lines, "Please fix the following 2 LSP Diagnostic(s) in this code:"))
  end)
end)
