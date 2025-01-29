---@diagnostic disable: undefined-global

require('gptmodels.types')
local util = require("gptmodels.util")
local assert = require("luassert")
local chat_window = require('gptmodels.windows.chat')
local stub = require('luassert.stub')
local llm = require('gptmodels.llm')
local Store = require('gptmodels.store')
local h = require('tests.gptmodels.spec_helpers')

describe("The Chat window", function()
  h.hook_reset_state()
  h.hook_seed_store()

  pending("opens in input mode", function()
    chat_window.build_and_mount()
    vim.api.nvim_feedkeys('xhello', 'mtx', true)
    -- For some reason, the first letter is always trimmed off. But if it's not in insert mode, the line will be empty ""
    assert.same(vim.api.nvim_get_current_line(), 'hello')
  end)

  it("puts selected text into input buffer", function()
    local win = chat_window.build_and_mount(h.generate_selection({ "selected text" }))
    local input_lines = h.get_popup_lines(win.input)
    assert.same({ "selected text" }, input_lines)
  end)

  it("opens with last chat", function()
    local content = "window should open with this content populated"

    Store.chat.chat:append({ role = "assistant", content = content })
    local win = chat_window.build_and_mount()
    local lines = h.get_popup_lines(win.chat)
    assert.equal(content, lines[1])
  end)

  it("clears all windows, kills job, removes files when opened with selected text", function()
    -- First, open a window and add some stuff
    local first_given_lines = { "first" }

    -- Open first time with a selection
    local selection = h.generate_selection(first_given_lines)
    chat_window.build_and_mount(selection)

    local llm_chat_stub = stub(llm, "chat")
    local fake_job = h.fake_job()
    llm_chat_stub.returns(fake_job)

    -- Send a request
    h.feed_keys('xhello<Esc><CR>')

    ---@type MakeChatRequestArgs
    local args = h.stub_args(llm_chat_stub)

    args.on_read(nil, { role = "assistant", content = "some content" }) -- populate chat pane

    -- add files
    Store.chat:append_file("README.md")

    -- close the window
    h.feed_keys(':q<CR>')

    local second_given_lines = { "second" }

    -- reopen window with new selection
    selection = h.generate_selection(second_given_lines)
    local win = chat_window.build_and_mount(selection)

    -- old job got killed
    assert(fake_job.done())

    -- both panes got cleared, input has new selection
    local chat_lines = h.get_popup_lines(win.chat)
    local input_lines = h.get_popup_lines(win.input)
    assert.same({ "" }, chat_lines)
    assert.same({ "second" }, input_lines)

    -- files were removed
    assert.same({}, Store.chat:get_filenames())
  end)

  it("shifts through windows on <Tab>", function()
    local win = chat_window.build_and_mount()
    local input_win = vim.fn.bufwinid(win.input.bufnr)
    local chat_win = vim.fn.bufwinid(win.chat.bufnr)

    h.feed_keys('<Esc>')
    assert.equal(vim.api.nvim_get_current_win(), input_win)
    h.feed_keys('<Tab>')
    assert.equal(vim.api.nvim_get_current_win(), chat_win)
    h.feed_keys('<Tab>')
    assert.equal(vim.api.nvim_get_current_win(), input_win)
  end)

  it("shifts through windows on <S-Tab>", function()
    local win = chat_window.build_and_mount()
    local input_win = vim.fn.bufwinid(win.input.bufnr)
    local chat_win = vim.fn.bufwinid(win.chat.bufnr)

    h.feed_keys('<Esc>')
    assert.equal(vim.api.nvim_get_current_win(), input_win)
    h.feed_keys('<S-Tab>')
    assert.equal(vim.api.nvim_get_current_win(), chat_win)
    h.feed_keys('<S-Tab>')
    assert.equal(vim.api.nvim_get_current_win(), input_win)
  end)

  it("Removes text from input and puts it in chat on <CR>", function()
    local win = chat_window.build_and_mount()

    h.feed_keys('ihello<Esc><CR>')

    -- ensure hello is one of the lines in chat buf
    local chat_lines = h.get_popup_lines(win.chat)
    assert.is_true(util.contains_line(chat_lines, "hello"))

    -- ensure input is empty
    local input_lines = h.get_popup_lines(win.input)
    assert.same(input_lines, { "" })

    -- ensure store's been cleared of input, since it's now empty
    assert.equal("", Store.chat.input:read())
  end)

  it("Places llm response into chat window", function()
    local win = chat_window.build_and_mount()

    -- stub llm call
    local llm_chat_stub = stub(llm, "chat")

    h.set_popup_lines(win.input, { "hello" })

    -- make call to llm stub
    h.feed_keys('<CR>')

    -- grab the given callback
    ---@type MakeChatRequestArgs
    local args = h.stub_args(llm_chat_stub)

    -- simulate llm responding
    args.on_read(nil, { role = "assistant", content = "response text1\nresponse text2" })

    -- Now the chat buffer should have all the things
    local chat_lines = h.get_popup_lines(win.chat)

    assert(util.contains_line(chat_lines, "hello"))
    assert(util.contains_line(chat_lines, "response text1"))
    assert(util.contains_line(chat_lines, "response text2"))
  end)

  it("clears all windows on <C-n>", function()
    local win = chat_window.build_and_mount()

    -- Populate windows with some content
    h.set_popup_lines(win.input, { "input content" })
    h.set_popup_lines(win.chat, { "chat content" })
    Store.chat:append_file("docs/gpt.txt")

    -- Press <C-n>
    h.feed_keys("<C-n>")

    -- Assert all windows are cleared
    assert.same({ '' }, h.get_popup_lines(win.input))
    assert.same({ '' }, h.get_popup_lines(win.chat))

    -- And the store of included files
    assert.same({}, Store.chat:get_filenames())
  end)

  -- Having a lot of trouble testing this.
  pending("updates and resizes the nui window when the vim window resized TODO", function()
    local win = chat_window.build_and_mount()

    local nui_height = vim.api.nvim_win_get_height(win.chat.winid)
    local nui_width = vim.api.nvim_win_get_width(win.chat.winid)

    local og_nui_height = nui_height
    local og_nui_width = nui_width

    -- Resize the Vim window
    vim.api.nvim_win_set_width(0, 200)
    vim.api.nvim_win_set_height(0, 300)

    vim.wait(20)

    nui_height = vim.api.nvim_win_get_height(win.chat.winid)
    nui_width = vim.api.nvim_win_get_width(win.chat.winid)

    assert.not_equals(og_nui_height, nui_height)
    assert.not_equals(og_nui_width, nui_width)
  end)
end)
