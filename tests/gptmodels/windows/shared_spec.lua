local util = require('gptmodels.util')
local assert = require("luassert")
local stub = require('luassert.stub')
local com = require('gptmodels.windows.common')
local cmd = require('gptmodels.cmd')
local ollama = require('gptmodels.providers.ollama')
local llm = require('gptmodels.llm')
local openai = require('gptmodels.providers.openai')
local chat_window = require('gptmodels.windows.chat')
local h = require('tests.gptmodels.spec_helpers')
local code_window = require('gptmodels.windows.code')
local Store = require('gptmodels.store')

-- What we'll iterate over, containing any differences required for the specs
-- Purpose here is to abstract a bunch of common logic. doze == windowz
local doze = {
  chat = {
    window = chat_window,
    name = "chat_window",
    -- where llm responses go
    response_pane = "chat",
    llm_request = "chat",
  },
  code = {
    window = code_window,
    name = "code_window",
    -- where llm responses go
    response_pane = "right",
    llm_request = "generate",
  }
}

for _, doe in pairs(doze) do
  describe(doe.name, function()
    h.hook_reset_state()
    h.hook_seed_store()

    it("sets wrap on all bufs, because these are small windows and that works better", function()
      -- First disable it globally, so the popups don't inherit the wrap from this test
      vim.wo[0].wrap = false

      local win = doe.window.build_and_mount()

      for _, pane in ipairs(win) do
        assert.equal(vim.wo[pane.winid].wrap, true)
      end
    end)

    it("closes the window on q", function()
      local win = doe.window.build_and_mount()

      -- Send a request
      h.feed_keys("q")

      -- assert window was closed
      assert.is_nil(win.input.winid)
      assert.is_nil(win.input.bufnr)
    end)

    it("saves input text on InsertLeave and prepopulate on reopen", function()
      local initial_input = "some initial input"
      doe.window.build_and_mount()

      -- Enter insert mode
      h.feed_keys("i" .. initial_input)

      -- <Esc> to trigger save
      h.feed_keys("<Esc>")

      -- Close the window with :q
      h.feed_keys(":q<CR>")

      -- Reopen the window
      local win = doe.window.build_and_mount()

      local input_lines = h.get_popup_lines(win.input)
      assert.same({ initial_input }, input_lines)
    end)

    it("opens a model picker on <C-p>", function()
      local select_model = h.stub_model_picker({ "abc.123.pie", index = 1 })

      local set_model_stub = stub(Store, "set_model")

      doe.window.build_and_mount()

      -- Open model picker
      h.feed_keys("<C-p>")

      -- Scroll a bit
      h.feed_keys("<Down>")

      select_model()

      assert.stub(set_model_stub).was_called(1)
      assert.equal('abc', h.stub_call_args(set_model_stub, 2))
      assert.equal('123.pie', h.stub_call_args(set_model_stub, 3))
    end)

    it("cycles through available models with <C-j>", function()
      Store:set_models("openai", {})
      Store:set_models("ollama", { "m1", "m2", "m3" })
      Store:set_model("ollama", "m1")

      doe.window.build_and_mount()

      Store:set_model("ollama", "m1")

      assert.equal("m1", Store:get_model().model)
      h.feed_keys("<C-j>")
      assert.equal("m2", Store:get_model().model)
      h.feed_keys("<C-j>")
      assert.equal("m3", Store:get_model().model)

      -- When initially set to a model that isn't present
      Store:set_model("ollama", "absent-model")
      h.feed_keys("<C-j>")
      assert.equal("m1", Store:get_model().model)
    end)

    it("cycles through available models with <C-k>", function()
      Store:set_models("openai", {})
      Store:set_models("ollama", { "m1", "m2", "m3" })
      Store:set_model("ollama", "m1")

      doe.window.build_and_mount()

      assert.equal("m1", Store:get_model().model)
      h.feed_keys("<C-k>")
      assert.equal("m3", Store:get_model().model)
      h.feed_keys("<C-k>")
      assert.equal("m2", Store:get_model().model)

      -- When initially set to a model that isn't present
      Store:set_model("ollama", "absent-model")
      h.feed_keys("<C-k>")
      assert.equal("m3", Store:get_model().model)
    end)

    it("includes files on <C-f> and clears them on <C-g>", function()
      doe.window.build_and_mount()

      local select_file = h.stub_file_picker({ "README.md", index = 1 })

      -- Press ctl-f to open the telescope picker
      h.feed_keys('<C-f>')

      -- Press enter to select the first file, was Makefile in testing
      h.feed_keys('<CR>')

      select_file()

      -- Now we'll check what was given to llm.generate
      local generate_stub = stub(llm, doe.llm_request)
      h.feed_keys('<CR>')

      ---@type MakeGenerateRequestArgs | MakeChatRequestArgs
      local args = h.stub_call_args(generate_stub)

      -- Does the request now contain the file
      if args.llm.prompt then
        assert(string.match(args.llm.prompt, "README.md"))
      else
        assert(string.match(args.llm.messages[1].content, "README.md"))
      end

      -- Now we'll make sure C-g clears the files
      h.feed_keys('<C-g>')
      h.feed_keys('<CR>')

      -- TODO h.stub_call_args should do both calls and refs
      ---@type MakeGenerateRequestArgs | MakeChatRequestArgs
      args = generate_stub.calls[2].refs[1]

      -- Does the request now contain a system string with the file
      if args.llm.prompt then
        assert.is_nil(string.match(args.llm.prompt, "README.md"))
      else
        assert.is_nil(string.match(args.llm.messages[3].content, "README.md"))
      end
    end)

    it("kills active job on <C-c>", function()
      doe.window.build_and_mount()
      local llm_request_stub = stub(llm, doe.llm_request)

      local fake_job = h.fake_job()
      llm_request_stub.returns(fake_job)

      -- Make a request to start a job
      h.feed_keys('xhello<Esc><CR>')

      -- press ctrl-c
      h.feed_keys('<C-c>')

      assert.is_true(fake_job.done())
    end)

    it("automatically scrolls display window when user is not in it", function()
      local win = doe.window.build_and_mount()

      local llm_stub = stub(llm, doe.llm_request)

      h.feed_keys('<CR>')

      ---@type MakeGenerateRequestArgs | MakeChatRequestArgs
      local args = h.stub_call_args(llm_stub)

      local long_content = ""
      for _ = 1, 1000, 1 do
        long_content = long_content .. "\n"
      end

      if doe.name == "code_window" then
        args.on_read(nil, long_content)
      elseif doe.name == "chat_window" then
        args.on_read(nil, {
          role = "assistant",
          content = long_content
        })
      else
        error("automatic scroll test encountered unknown window")
      end

      local last_line = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(win[doe.response_pane].winid))
      local win_height = vim.api.nvim_win_get_height(win[doe.response_pane].winid)
      local expected_scroll = last_line - win_height + 1
      local actual_scroll = vim.fn.line('w0', win[doe.response_pane].winid)

      assert.equal(expected_scroll, actual_scroll)

      -- Now press s-tab to get into the window
      h.feed_keys('<S-Tab>')

      -- Another big response
      if doe.name == "code_window" then
        args.on_read(nil, long_content)
      elseif doe.name == "chat_window" then
        args.on_read(nil, {
          role = "assistant",
          content = long_content
        })
      else
        error("automatic scroll test encountered unknown window")
      end

      -- This time we should stay put
      expected_scroll = actual_scroll -- unchanged since last check
      actual_scroll = vim.fn.line('w0', win[doe.response_pane].winid)

      assert.equal(expected_scroll, actual_scroll)

      -- Now we'll close the window to later reopen it
      h.feed_keys(':q<CR>')

      -- reopen the closed window
      win = doe.window.build_and_mount()

      -- more long responses come in from the llm
      if doe.name == "code_window" then
        args.on_read(nil, long_content)
      elseif doe.name == "chat_window" then
        args.on_read(nil, {
          role = "assistant",
          content = long_content
        })
      else
        error("automatic scroll test encountered unknown window")
      end

      -- and now ensure the autoscrolling continues to happen
      last_line = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(win[doe.response_pane].winid))
      win_height = vim.api.nvim_win_get_height(win[doe.response_pane].winid)
      expected_scroll = last_line - win_height + 1
      actual_scroll = vim.fn.line('w0', win[doe.response_pane].winid)

      assert.equal(expected_scroll, actual_scroll)
    end)

    it("finishes jobs in the background when closed", function()
      doe.window.build_and_mount()
      local chat_stub = stub(llm, doe.llm_request)
      local die_called = false

      local fake_job = h.fake_job()
      chat_stub.returns(fake_job)

      -- Make a request to start a job
      h.feed_keys('ihello<Esc><CR>')

      -- quit with :q
      h.feed_keys('<Esc>:q<CR>')

      assert.is_not.True(die_called)

      -- -- simulate hint of wait time for the nui windows to close
      -- -- This leads to errors about invalid windows.
      -- -- Might be nui issue, see code_spec
      -- vim.wait(10)

      ---@type MakeChatRequestArgs | MakeGenerateRequestArgs
      local args = h.stub_call_args(chat_stub)

      if args.llm.prompt then
        args.on_read(nil, "response to be saved in background")
      else
        args.on_read(nil, { role = "assistant", content = "response to be saved in background" })
      end

      -- Open up and ensure it's there now
      local win = doe.window.build_and_mount()
      assert(util.contains_line(vim.api.nvim_buf_get_lines(win[doe.response_pane].bufnr, 0, -1, true),
        "response to be saved in background"))


      -- More reponse to still reopen window
      if args.llm.prompt then
        args.on_read(nil, "\nadditional response")
      else
        args.on_read(nil, { role = "assistant", content = "\nadditional response" })
      end

      -- Gets that response without reopening
      local display_lines = vim.api.nvim_buf_get_lines(win[doe.response_pane].bufnr, 0, -1, true)
      assert(util.contains_line(display_lines, "response to be saved in background"))
      assert(util.contains_line(display_lines, "additional response"))
    end)

    it("fetches models when started (etl)", function()
      Store:set_models("openai", { "ma1", "ma2" })
      Store:set_models("ollama", { "m1", "m2" })
      Store:set_model("ollama", "m1")

      local fetch_ollama_models_stub = stub(ollama, "fetch_models")
      fetch_ollama_models_stub.invokes(function(on_complete)
        on_complete(nil, { "ollama1", "ollama2" })
      end)

      local fetch_openai_models_stub = stub(openai, "fetch_models")
      fetch_openai_models_stub.invokes(function(on_complete)
        on_complete(nil, { "openai1", "openai2" })
      end)

      doe.window.build_and_mount()

      assert.stub(fetch_ollama_models_stub).was_called(1)
      assert.stub(fetch_openai_models_stub).was_called(1)
      assert.same({ "ollama1", "ollama2" }, Store:get_models("ollama"))
      assert.same({ "openai1", "openai2" }, Store:get_models("openai"))

      doe.window.build_and_mount()

      assert.stub(fetch_ollama_models_stub).was_called(2)
      assert.stub(fetch_openai_models_stub).was_called(2)
      assert.same({ "ollama1", "ollama2" }, Store:get_models("ollama"))
      assert.same({ "openai1", "openai2" }, Store:get_models("openai"))
    end)

    it("alerts the user when required dependencies are not installed", function()
      local notify_stub = stub(vim, 'notify_once')

      local exec_stub = stub(cmd, "exec")
      ---@param exec_args ExecArgs
      exec_stub.invokes(function(exec_args)
        if exec_args.testid == "check-deps-errors" or exec_args.testid == "check-deps-warnings" then
          -- simulate a miss from `which`
          exec_args.onexit(1, 15)
        end
      end)

      local has_env_var_stub = stub(util, "has_env_var")
      has_env_var_stub.returns(false)

      doe.window.build_and_mount()

      assert.stub(has_env_var_stub).was_called(1)
      assert.stub(notify_stub).was_called(2)

      -----Leaving here for the full type hint
      -----@type [string, integer|nil, table|nil]
      --local notify_args = notify_stub.calls[1].refs

      -- Ensure that one call contains the missing required dep "curl" and the
      -- other contains the optional "ollama"
      -- TODO Move this test and the one in chat_spec to common_spec and just check in both of these
      -- that check_deps is being called
      local error_message =
      "GPTModels.nvim is missing `curl`, which is required."
      .. " The plugin will not work."
      .. " GPTModels.nvim is missing both the OPENAI_API_KEY env var and the `ollama` executable."
      .. " The plugin will have no models and will not work. "

      local info_message =
      "GPTModels.nvim is missing optional dependency `ollama`."
      .. " Local ollama models will be unavailable."
      .. " GPTModels.nvim is missing optional OPENAI_API_KEY env var."
      .. " openai models will be unavailable. "

      -- number of notify calls
      for i = 1, 2 do
        ---@type string | integer
        local ref = notify_stub.calls[i].refs[1]
        if ref ~= error_message and ref ~= info_message then
          assert(false, "Received unexpected notification: " .. ref)
        end
      end
    end)

    it("sets input bottom border text on launch", function()
      local set_text_stub = stub(com, "set_input_bottom_border_text")
      local win = doe.window.build_and_mount()
      assert.stub(set_text_stub).was_called(1)
      local args = h.stub_call_args(set_text_stub)
      assert.equal(args, win.input)
    end)

    it("handles errors gracefully - curl error messages appear on screen", function()
      h.stub_schedule_wrap()

      Store:set_models("ollama", { "m" })
      Store:set_model("ollama", "m")

      local exec_stub = stub(cmd, "exec")
      ---@param exec_args ExecArgs
      exec_stub.invokes(function(exec_args)
        -- multiple calls will take place, only the one for ollama chat or generation we care about
        if exec_args.testid and exec_args.testid:sub(1, 6) == "ollama" then
          -- sometimes requests are broken into multiple - system must concat correctly.
          exec_args.onread("curl ")
          exec_args.onread("error")
        end
      end)

      local win = doe.window.build_and_mount()

      -- Send a request
      h.feed_keys('ihello<Esc><CR>')

      local displayed_lines = h.get_popup_lines(win[doe.response_pane])
      assert(util.contains_line(displayed_lines, "curl error"))
    end)
  end)
end
