---@diagnostic disable: undefined-global

local util        = require("gptmodels.util")
local assert      = require("luassert")
local code_window = require('gptmodels.windows.code')
local stub        = require('luassert.stub')
local llm         = require('gptmodels.llm')
local Store       = require('gptmodels.store')
local h           = require('tests.gptmodels.spec_helpers')

describe("The code window", function()
  h.hook_reset_state()
  h.hook_seed_store()

  it("places provided selected text in left window", function()
    local given_lines = { "text line 1", "text line 2" }
    local win = code_window.build_and_mount(h.generate_selection(given_lines))
    local gotten_lines = h.get_popup_lines(win.left)
    assert.same(given_lines, gotten_lines)
  end)

  it("clears all windows, kills job, and clears files when opened with selected text", function()
    -- First, open a window and add some stuff
    local first_given_lines = { "first" }
    code_window.build_and_mount(h.generate_selection(first_given_lines)) -- populate left pane

    local llm_stub = stub(llm, "generate")
    local fake_job = h.fake_job()
    llm_stub.returns(fake_job)

    -- Send a request
    h.feed_keys('xhello<Esc><CR>')

    ---@type MakeGenerateRequestArgs
    local args = h.stub_call_args(llm_stub)

    args.on_read(nil, "some content") -- populate right pane

    -- add files
    Store.code:append_file("README.md")

    -- close the window
    h.feed_keys(':q<CR>')

    local second_given_lines = { "second" }

    -- reopen window with new selection
    local win = code_window.build_and_mount(h.generate_selection(second_given_lines))

    -- old job got killed
    assert(fake_job.done())

    -- all panes got cleared, left has new selection
    local left_lines = h.get_popup_lines(win.left)
    local right_lines = h.get_popup_lines(win.right)
    local input_lines = h.get_popup_lines(win.input)
    assert.same(second_given_lines, left_lines)
    assert.same({ "" }, right_lines)
    assert.same({ "" }, input_lines)

    -- files were removed
    assert.same({}, Store.code:get_filenames())
  end)

  it("shifts through windows on <Tab>", function()
    local win = code_window.build_and_mount()

    local input_win = vim.fn.bufwinid(win.input.bufnr)
    local left_win = vim.fn.bufwinid(win.left.bufnr)
    local right_win = vim.fn.bufwinid(win.right.bufnr)

    h.feed_keys('<Esc>')
    assert.equal(vim.api.nvim_get_current_win(), input_win)
    h.feed_keys('<Tab>')
    assert.equal(vim.api.nvim_get_current_win(), left_win)
    h.feed_keys('<Tab>')
    assert.equal(vim.api.nvim_get_current_win(), right_win)
    h.feed_keys('<Tab>')
    assert.equal(vim.api.nvim_get_current_win(), input_win)
  end)

  it("shifts through windows on <S-Tab>", function()
    local win = code_window.build_and_mount()
    local input_win = vim.fn.bufwinid(win.input.bufnr)
    local left_win = vim.fn.bufwinid(win.left.bufnr)
    local right_win = vim.fn.bufwinid(win.right.bufnr)

    h.feed_keys('<Esc>')
    assert.equal(vim.api.nvim_get_current_win(), input_win)
    h.feed_keys('<S-Tab>')
    assert.equal(vim.api.nvim_get_current_win(), right_win)
    h.feed_keys('<S-Tab>')
    assert.equal(vim.api.nvim_get_current_win(), left_win)
    h.feed_keys('<S-Tab>')
    assert.equal(vim.api.nvim_get_current_win(), input_win)
  end)

  it("Places llm responses into right window", function()
    local win = code_window.build_and_mount()

    local generate_stub = stub(llm, "generate")

    h.feed_keys('xhello<Esc><CR>')

    ---@type MakeGenerateRequestArgs
    local args = h.stub_call_args(generate_stub)

    -- simulate a multiline resposne from the llm
    args.on_read(nil, "line 1\nline 2")

    -- Those lines should be separated on newlines and placed into the right buf
    assert.same({ "line 1", "line 2" }, h.get_popup_lines(win.right))
  end)

  it("includes a system prompt", function()
    code_window.build_and_mount()
    local generate_stub = stub(llm, "generate")

    -- Make a request to start a job
    h.feed_keys('xincluding system prompt?<Esc><CR>')

    ---@type MakeGenerateRequestArgs
    local args = h.stub_call_args(generate_stub)
    assert.not_nil(args.llm.system)
  end)

  it("includes file type", function()
    vim.bo[0].filetype = "lua"
    code_window.build_and_mount()

    local generate_stub = stub(llm, "generate")

    -- Make a request to start a job
    h.feed_keys('xincluding filetype?<Esc><CR>')

    ---@type MakeGenerateRequestArgs
    local args = h.stub_call_args(generate_stub)

    assert.not_nil(string.find(args.llm.prompt, "lua"))
    assert.not_nil(args.llm.prompt)
  end)

  it("Has a loading indicator", function()
    local win = code_window.build_and_mount()

    local generate_stub = stub(llm, "generate")

    h.feed_keys('xloading test<Esc><CR>')

    ---@type MakeGenerateRequestArgs
    local args = h.stub_call_args(generate_stub)

    -- before on_response gets a response from the llm, the right window should show a loading indicator
    assert.same({ "Loading..." }, h.get_popup_lines(win.right))

    -- simulate a response from the llm
    args.on_read(nil, "response line")

    -- After the response, the loading indicator should be replaced by the response
    assert.same({ "response line" }, h.get_popup_lines(win.right))
  end)

  it("does not open prepopulated w/ prior session when text is provided", function()
    Store.code.right:append("right content")
    Store.code.input:append("input content")
    Store.code.left:append("left content")

    local win = code_window.build_and_mount(h.generate_selection({ "provided text" }))

    assert.same({ "" }, h.get_popup_lines(win.right))
    assert.same({ "" }, h.get_popup_lines(win.input))
    assert.same({ "provided text" }, h.get_popup_lines(win.left))
  end)

  it("Replaces prior llm response with new one", function()
    local win = code_window.build_and_mount()

    local generate_stub = stub(llm, "generate")

    -- Input anything
    h.feed_keys('xtesting first response<Esc><CR>')

    ---@type MakeGenerateRequestArgs
    local args_first = h.stub_call_args(generate_stub)

    -- Simulate first response
    args_first.on_read(nil, "first response line")
    if args_first.on_end then args_first.on_end() end

    -- Response is shown
    assert.same({ "first response line" }, h.get_popup_lines(win.right))

    -- Input whatever
    h.feed_keys('xtesting second response<Esc><CR>')

    ---@type MakeGenerateRequestArgs
    local args_second = h.stub_call_args(generate_stub)

    -- Simulate second response
    args_second.on_read(nil, "second response line")

    -- Second response replaced first response
    assert.same({ "second response line" }, h.get_popup_lines(win.right))
  end)

  it("clears all windows on <C-n>", function()
    local win = code_window.build_and_mount()

    -- Populate windows with some content
    h.set_popup_lines(win.input, { "input content" })
    h.set_popup_lines(win.left, { "left content" })
    h.set_popup_lines(win.right, { "right content" })
    Store.code:append_file("docs/gpt.txt")

    -- Press <C-n>
    h.feed_keys('<C-n>')

    -- Assert all windows are cleared
    assert.same({ '' }, h.get_popup_lines(win.input))
    assert.same({ '' }, h.get_popup_lines(win.left))
    assert.same({ '' }, h.get_popup_lines(win.right))

    -- And the store of included files
    assert.same({}, Store.code:get_filenames())
  end)

  it("transfers contents of right pane to left pane on <C-x> (xfer)", function()
    local win = code_window.build_and_mount()

    local generate_stub = stub(llm, "generate")

    -- Send a request
    h.feed_keys("itransfer panes<Esc><CR>")

    ---@type MakeGenerateRequestArgs
    local args = h.stub_call_args(generate_stub)

    -- Get some stuff into the right pane, this will get transfered around
    args.on_read(nil, "xfer")

    -- It's in the right pane, see?
    assert.same({ "xfer" }, h.get_popup_lines(win.right))

    -- Send a request
    h.feed_keys("<C-x>")

    -- Now it's in the left pane
    assert.same({ "xfer" }, h.get_popup_lines(win.left))

    -- And not in the right pane
    assert.same({ "" }, h.get_popup_lines(win.right))
  end)

  it("saves state of all three windows and prepopulates them on reopen", function()
    local llm_stub = stub(llm, "generate")

    -- left window is saved when it opens
    local win = code_window.build_and_mount(h.generate_selection({ "left" }))

    -- Add user input
    h.set_popup_lines(win.input, { "input" })

    -- Enter insert mode, so we can leave it
    h.feed_keys("i")

    -- <Esc> triggers save
    h.feed_keys("<Esc>")

    -- <CR> triggers llm call
    h.feed_keys("<CR>")

    -- right window is saved when an llm response comes in
    ---@type MakeGenerateRequestArgs
    local args = h.stub_call_args(llm_stub)
    args.on_read(nil, "right")

    -- Close the window with :q
    h.feed_keys(":q<CR>")

    -- Reopen the window
    win = code_window.build_and_mount()

    assert.same({ "input" }, h.get_popup_lines(win.input))
    assert.same({ "left" }, h.get_popup_lines(win.left))
    assert.same({ "right" }, h.get_popup_lines(win.right))
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

    local win = code_window.build_and_mount(selection)

    local input_lines = h.get_popup_lines(win.input)
    assert.stub(get_diagnostic_stub).was_called(1)
    assert(util.contains_line(input_lines, "Please fix the following 2 LSP Diagnostic(s) in this code:"))

    -- close window
    h.feed_keys(':q<CR>')

    -- reopen
    win = code_window.build_and_mount()

    -- lines should remain in input window
    input_lines = h.get_popup_lines(win.input)
    assert(util.contains_line(input_lines, "Please fix the following 2 LSP Diagnostic(s) in this code:"))
  end)
end)
