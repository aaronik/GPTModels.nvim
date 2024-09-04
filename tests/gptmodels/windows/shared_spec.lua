local util = require('gptmodels.util')
local assert = require("luassert")
local stub = require('luassert.stub')
local com = require('gptmodels.windows.common')
local cmd = require('gptmodels.cmd')
local ollama = require('gptmodels.providers.ollama')
local openai = require('gptmodels.providers.openai')
local chat_window = require('gptmodels.windows.chat')
local helpers = require('tests.gptmodels.spec_helpers')
local code_window = require('gptmodels.windows.code')
local Store = require('gptmodels.store')

-- What we'll iterate over, containing any differences required for the specs
-- Purpose here is to abstract a bunch of common logic
local doze = {
  chat = {
    window = chat_window,
    name = "chat_window",
  },
  code = {
    window = code_window,
    name = "code_window",
  }
}

-- Felt cute, might delete later
local they = it

for _, doe in pairs(doze) do
  describe("[" .. doe.name .. "] Both windows", function()
    helpers.reset_state()

    they("set wrap on all bufs, because these are small windows and that works better", function()
      -- First disable it globally, so the popups don't inherit the wrap from this test
      vim.wo[0].wrap = false

      local win = doe.window.build_and_mount()

      for _, pane in ipairs(win) do
        assert.equal(vim.wo[pane.winid].wrap, true)
      end
    end)

    they("close the window on q", function()
      local win = doe.window.build_and_mount()

      -- Send a request
      helpers.feed_keys("q")

      -- assert window was closed
      assert.is_nil(win.input.winid)
      assert.is_nil(win.input.bufnr)
    end)

    they("save input text on InsertLeave and prepopulate on reopen", function()
      local initial_input = "some initial input"
      local win = doe.window.build_and_mount()

      -- Enter insert mode
      helpers.feed_keys("i" .. initial_input)

      -- <Esc> to trigger save
      helpers.feed_keys("<Esc>")

      -- Close the window with :q
      helpers.feed_keys(":q<CR>")

      -- Reopen the window
      win = doe.window.build_and_mount()

      local input_lines = vim.api.nvim_buf_get_lines(win.input.bufnr, 0, -1, true)
      assert.same({ initial_input }, input_lines)
    end)

    they("open a model picker on <C-p>", function()
      -- For down the line of this crazy stubbing exercise
      local get_selected_entry_stub = stub(require('telescope.actions.state'), "get_selected_entry")
      get_selected_entry_stub.returns({ "abc.123.pie", index = 1 }) -- typical response

      -- And just make sure there are no closing errors
      stub(require('telescope.actions'), "close")

      local set_model_stub = stub(Store, "set_model")

      local new_picker_stub = stub(require('telescope.pickers'), "new")
      new_picker_stub.returns({ find = function() end })

      doe.window.build_and_mount()

      -- Open model picker
      local c_m = vim.api.nvim_replace_termcodes("<C-p>", true, true, true)
      vim.api.nvim_feedkeys(c_m, 'mtx', true)

      assert.stub(new_picker_stub).was_called(1)

      -- Type whatever nonsense and press enter
      local search = vim.api.nvim_replace_termcodes("<CR>", true, true, true)
      vim.api.nvim_feedkeys(search, 'mtx', true)

      local attach_mappings = new_picker_stub.calls[1].refs[1].attach_mappings
      local map = stub()
      map.invokes(function(_, _, cb)
        cb(9999) -- this will call get_selected_entry internally
      end)
      attach_mappings(nil, map)

      assert.stub(set_model_stub).was_called(1)
      assert.equal('abc', set_model_stub.calls[1].refs[2])
      assert.equal('123.pie', set_model_stub.calls[1].refs[3])
    end)

    they("cycle through available models with <C-j>", function()
      Store:set_models("ollama", { "m1", "m2", "m3" })
      Store:set_model("ollama", "m1")

      doe.window.build_and_mount()

      Store:set_model("ollama", "m1")

      assert.equal("m1", Store:get_model().model)
      helpers.feed_keys("<C-j>")
      assert.equal("m2", Store:get_model().model)
      helpers.feed_keys("<C-j>")
      assert.equal("m3", Store:get_model().model)

      -- When initially set to a model that isn't present
      Store:set_model("ollama", "absent-model")
      helpers.feed_keys("<C-j>")
      assert.equal("m1", Store:get_model().model)
    end)

    they("cycle through available models with <C-k>", function()
      Store:set_models("ollama", { "m1", "m2", "m3" })
      Store:set_model("ollama", "m1")

      doe.window.build_and_mount()

      assert.equal("m1", Store:get_model().model)
      helpers.feed_keys("<C-k>")
      assert.equal("m3", Store:get_model().model)
      helpers.feed_keys("<C-k>")
      assert.equal("m2", Store:get_model().model)

      -- When initially set to a model that isn't present
      Store:set_model("ollama", "absent-model")
      helpers.feed_keys("<C-k>")
      assert.equal("m3", Store:get_model().model)
    end)

    they("fetch models when started (etl)", function()
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

    they("alert the user when required dependencies are not installed", function()
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
      "GPTModels.nvim is missing `curl`, which is required. The plugin will not work. GPTModels.nvim is missing both the OPENAI_API_KEY env var and the `ollama` executable. The plugin will have no models and will not work. "
      local info_message =
      "GPTModels.nvim is missing optional dependency `ollama`. Local ollama models will be unavailable. GPTModels.nvim is missing optional OPENAI_API_KEY env var. openai models will be unavailable. "

      -- number of notify calls
      for i = 1, 2 do
        ---@type string | integer
        local ref = notify_stub.calls[i].refs[1]
        if ref ~= error_message and ref ~= info_message then
          assert(false, "Received unexpected notification: " .. ref)
        end
      end
    end)

    they("set input bottom border text on launch", function()
      local set_text_stub = stub(com, "set_input_bottom_border_text")
      local chat = doe.window.build_and_mount()
      assert.stub(set_text_stub).was_called(1)
      local args = set_text_stub.calls[1].refs
      assert.equal(args[1], chat.input)
    end)
  end)
end
