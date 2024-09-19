---@diagnostic disable: undefined-global

require('gptmodels.types')
local util = require("gptmodels.util")
local assert = require("luassert")
local chat_window = require('gptmodels.windows.chat')
local stub = require('luassert.stub')
local spy = require('luassert.spy')
local llm = require('gptmodels.llm')
local cmd = require('gptmodels.cmd')
local Store = require('gptmodels.store')
local ollama = require('gptmodels.providers.ollama')
local helpers = require('tests.gptmodels.spec_helpers')
local com = require('gptmodels.windows.common')

describe("The Chat window", function()
  helpers.reset_state()
  helpers.seed_store()

  pending("opens in input mode", function()
    chat_window.build_and_mount()
    vim.api.nvim_feedkeys('xhello', 'mtx', true)
    -- For some reason, the first letter is always trimmed off. But if it's not in insert mode, the line will be empty ""
    assert.same(vim.api.nvim_get_current_line(), 'hello')
  end)

  it("puts selected text into input buffer", function()
    local chat = chat_window.build_and_mount(helpers.build_selection({ "selected text" }))
    local input_lines = vim.api.nvim_buf_get_lines(chat.input.bufnr, 0, -1, true)
    assert.same({ "selected text" }, input_lines)
  end)

  it("opens with last chat", function()
    local content = "window should open with this content populated"
    Store.chat.chat:append({ role = "assistant", content = content })

    local chat = chat_window.build_and_mount()
    local chat_bufnr = chat.chat.bufnr

    local lines = vim.api.nvim_buf_get_lines(chat_bufnr, 0, -1, true)
    assert.equal(content, lines[1])
  end)

  it("clears all windows, kills job, removes files when opened with selected text", function()
    -- First, open a window and add some stuff
    local first_given_lines = { "first" }
    local chat = chat_window.build_and_mount(helpers.build_selection(first_given_lines)) -- populate input a bit

    local die_called = false

    local llm_stub = stub(llm, "chat")
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

    ---@type MakeChatRequestArgs
    local args = llm_stub.calls[1].refs[1]

    args.on_read(nil, { role = "assistant", content = "some content" }) -- populate chat pane

    -- add files
    Store.chat:append_file("README.md")

    -- close the window
    keys = vim.api.nvim_replace_termcodes(':q<CR>', true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', false) -- populate input, fire request

    local second_given_lines = { "second" }

    -- reopen window with new selection
    chat = chat_window.build_and_mount(helpers.build_selection(second_given_lines))

    -- old job got killed
    assert(die_called)

    -- both panes got cleared, input has new selection
    local chat_lines = vim.api.nvim_buf_get_lines(chat.chat.bufnr, 0, -1, true)
    local input_lines = vim.api.nvim_buf_get_lines(chat.input.bufnr, 0, -1, true)
    assert.same({ "" }, chat_lines)
    assert.same({ "second" }, input_lines)

    -- files were removed
    assert.same({}, Store.chat:get_files())
  end)

  it("shifts through windows on <Tab>", function()
    local chat = chat_window.build_and_mount()
    local input_bufnr = chat.input.bufnr
    local chat_bufnr = chat.chat.bufnr

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
    local chat = chat_window.build_and_mount()
    local input_bufnr = chat.input.bufnr
    local chat_bufnr = chat.chat.bufnr

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

  it("Removes text from input and puts it in chat on <CR>", function()
    local chat = chat_window.build_and_mount()
    local input_bufnr = chat.input.bufnr
    local chat_bufnr = chat.chat.bufnr

    local keys = vim.api.nvim_replace_termcodes('ihello<Esc><CR>', true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', false)

    local chat_lines = vim.api.nvim_buf_get_lines(chat_bufnr, 0, -1, true)

    -- ensure hello is one of the lines in chat buf
    assert.is_true(util.contains_line(chat_lines, "hello"))

    -- ensure input is empty
    local input_lines = vim.api.nvim_buf_get_lines(input_bufnr, 0, -1, true)
    assert.same(input_lines, { "" })

    -- ensure store's been cleared of input, since it's now empty
    assert.equal("", Store.chat.input:read())
  end)

  it("Places llm response into chat window", function()
    local chat = chat_window.build_and_mount()
    local input_bufnr = chat.input.bufnr
    local chat_bufnr = chat.chat.bufnr

    -- stub llm call
    local chat_stub = stub(llm, "chat")

    vim.api.nvim_buf_set_lines(input_bufnr, 0, -1, true, { "hello" })

    -- make call to llm stub
    local keys = vim.api.nvim_replace_termcodes('<CR>', true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', false)

    -- grab the given callback
    ---@type MakeChatRequestArgs
    local args = chat_stub.calls[1].refs[1]

    -- simulate llm responding
    args.on_read(nil, { role = "assistant", content = "response text1\nresponse text2" })

    -- Now the chat buffer should have all the things
    local chat_lines = vim.api.nvim_buf_get_lines(chat_bufnr, 0, -1, true)

    assert(util.contains_line(chat_lines, "hello"))
    assert(util.contains_line(chat_lines, "response text1"))
    assert(util.contains_line(chat_lines, "response text2"))
  end)

  it("clears all windows on <C-n>", function()
    local chat = chat_window.build_and_mount()

    -- Populate windows with some content
    vim.api.nvim_buf_set_lines(chat.input.bufnr, 0, -1, true, { "input content" })
    vim.api.nvim_buf_set_lines(chat.chat.bufnr, 0, -1, true, { "chat content" })
    Store.chat:append_file("docs/gpt.txt")

    -- Press <C-n>
    local keys = vim.api.nvim_replace_termcodes("<C-n>", true, true, true)
    vim.api.nvim_feedkeys(keys, 'mtx', true)

    -- Assert all windows are cleared
    assert.same({ '' }, vim.api.nvim_buf_get_lines(chat.input.bufnr, 0, -1, true))
    assert.same({ '' }, vim.api.nvim_buf_get_lines(chat.chat.bufnr, 0, -1, true))

    -- And the store of included files
    assert.same({}, Store.chat:get_files())
  end)

  -- Having a lot of trouble testing this.
  pending("updates and resizes the nui window when the vim window resized TODO", function()
    local chat = chat_window.build_and_mount()

    local nui_height = vim.api.nvim_win_get_height(chat.chat.winid)
    local nui_width = vim.api.nvim_win_get_width(chat.chat.winid)

    local og_nui_height = nui_height
    local og_nui_width = nui_width

    -- Resize the Vim window
    vim.api.nvim_win_set_width(0, 200)
    vim.api.nvim_win_set_height(0, 300)

    vim.wait(20)

    nui_height = vim.api.nvim_win_get_height(chat.chat.winid)
    nui_width = vim.api.nvim_win_get_width(chat.chat.winid)

    assert.not_equals(og_nui_height, nui_height)
    assert.not_equals(og_nui_width, nui_width)
  end)
end)
