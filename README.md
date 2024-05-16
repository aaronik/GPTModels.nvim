<span><img alt="Static Badge" src="https://img.shields.io/badge/100%25_lua-purple"></span>
<a href="https://www.vim.org/"><img src="https://img.shields.io/badge/VIM-%2311AB00.svg?style=for-the-badge&amp;logo=vim&amp;logoColor=white" alt="Vim"></a>
<a href="https://neovim.io/"><img src="https://img.shields.io/badge/NeoVim-%2357A143.svg?&amp;style=for-the-badge&amp;logo=neovim&amp;logoColor=white" alt="Neovim"></a>

# GPTModels.nvim - an LLM AI plugin for neovim

This is an iteration on the window features of [jackMort/ChatGPT.nvim].
It's an AI plugin designed to tighten your neovim workflow with AI LLMs.
It offers two windows: one for chat, and one for code editing.

The plugin is developed with a focus on **stability** and **user experience**.
The plugin code is **well tested**, and leverages the **EmmyLua** type system for robustness.

---

### Features

* **Supports OpenAI and Ollama** - Local LLMs can be amazing as well. This plugin makes it super simple to switch between different models. I often get "second opinions" on code I'm getting LLM help with.
* **File inclusion** - The plugin uses telescope for a super clean file picker, and includes the files in the messages to the llm.
* **Background processing** - Close the window while the AI responds, open the window and the response will continue streaming in the background.
* **Request cancellation** - Cancel requests midflight with Ctrl-c. Save tokens and time.
* **Selection inclusion** - Both windows, when opened with selected text, bring that selected text into the window for inclusion in your llm request. Opening with a selection clears the old session automatically.
* **Filetype inclusion** - The file's extension is included in llm requests so you don't have to specify what kind of code it is when supplying smaller amounts of code
* **Stability** - This was written test first, and always will be. It also makes heavy use of the EmmyLua type system, which makes the code more robust. There still may be bugs, but hopefully there'll be fewer at least.
* **UX in mind** - It's hard to enumerate the little things, but I hope and think you'll notice them as you use the plugin. Examples include keeping sessions across close in both windows, saving the prompt window after you type stuff before you send the request, so you can slowly build up the request, scrolls on llm responses unless you're in the window, so you can interact with the response before it's finished, responsive window resizing when terminal window changes size, and more little things like this.

### Usage

This plugin offers two commands:

* `:GPTModelsCode` - open a window designed to iterate on selections of code
      <details>
        <summary>See example of :GPTModelsCode</summary>
        <img width="1271" alt="image of :GPTChat window" src="https://github.com/Aaronik/GPT.nvim/assets/1324601/3e642a48-ce56-4295-a5fa-368b523bab2e">
      </details>
* `:GPTModelsChat` - open a chat window, like ChatGPT
      <details>
        <summary>See example of :GPTModelsChat</summary>
        <img width="1271" alt="image of :GPTCode window" src="https://github.com/Aaronik/GPT.nvim/assets/1324601/ca6604af-302f-4a44-8964-bb683633031e">
      </details>

**The code window** (:GPTModelsCode) is great for iterating on a selection of code.
You have three panes - the left pane holds code you're working on, the right pane
code only responses from the LLMs,
and then you have an input for your prompt.
If you call it with a visual selection, that selection will be placed into the left pane.
From there you can iterate on the code. Press Ctrl-x to replace the left pane with
the contents of the right, rinse and repeat. This window is also nice because the
code is the main focus, and has syntax highlighting. I use this whenever I have
an AI request about code I'm working on. The prompt behind the scenes is tuned so the
AI only responds with code (although some LLMs are harder to get perfect, so be lenient.)
Other features, including changing models and including files, are labeled on the window.

**The chat window** is great for having a free form conversation. You can still open with
a selection, include files, cancel requests, etc.

#### Keymaps

The keymaps strive to be labaled and easily visible from within the plugin so you don't need to reference
them here. But here they are anyways:

| Keybinding | Action           | Description      |
|------------|------------------|------------------|
| `q`        | quit             | close the window |
| `[S]Tab`   | cycle windows    | switch focus into each window successively |
| `C-c`      | cancel request   | send SIGTERM to the `curl` command making the fetch |
| `C-f`      | add files        | open the file picker window and include file contents in your request |
| `C-g`      | clear files      | clear the files you have selected, leaving the windows be |
| `C-x`      | xfer to deck     | in the code window, transfer the right pane's contents to the left |
| `C-j/k`    | cycle models     | cycle through which LLM model to use for further requests |
| `C-n`      | clear all        | clear the whole state, all the windows and files |


---

### Installation

This plugin requires `curl` be installed for requests.
For Ollama requests, have [Ollama](https://ollama.com/) running locally.
For OpenAI requests, have the `OPENAI_API_KEY` environment variable set.

Now, in your favorite package manager:

lazy:
```lua
{
  "Aaronik/GPTModels.nvim",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "nvim-telescope/telescope.nvim"
  }
}
```

Plug:
```vim
Plug "MunifTanjim/nui.nvim"
Plug "nvim-telescope/telescope.nvim"
Plug "Aaronik/GPTModels.nvim"
```

_(Contributions to this readme for how to do other package managers are welcome)_

#### Mapping

Here are some examples of how to map these -- this is what I use, `<leader>a` for the code window and `<leader>c` for the chat

in `init.lua`:
```lua
-- Both visual and normal mode for each, so you can open with a visual selection or without.
vim.api.nvim_set_keymap('v', '<leader>a', ':GPTModelsCode<CR>', { noremap = true })
vim.api.nvim_set_keymap('n', '<leader>a', ':GPTModelsCode<CR>', { noremap = true })

vim.api.nvim_set_keymap('v', '<leader>c', ':GPTModelsChat<CR>', { noremap = true })
vim.api.nvim_set_keymap('n', '<leader>c', ':GPTModelsChat<CR>', { noremap = true })
```

in `.vimrc`:
```vim
" Or if you prefer the traditional way
nnoremap <leader>a :GPTModelsCode<CR>
vnoremap <leader>a :GPTModelsCode<CR>

nnoremap <leader>c :GPTModelsChat<CR>
vnoremap <leader>c :GPTModelsChat<CR>
```

### Thanks

Big thanks to [@jackMort](https://github.com/jackMort) for the inspiration for the code window. I used [jackMort/ChatGPT.nvim](https://github.com/jackMort/ChatGPT.nvim) for a long time before deciding to write this plugin.

#### TODO

* Source available ollama models from ollama ls
* :h gpt works but :h gptmodels doesn't
* code needs C-y?
* Focus same buffer on nui exit?
* Add copilot support .. Very hard as it turns out
* Protect against opening windows many times?
* Figure out how to test nui border text and test all the titles
* A nice architectural feature would be to just have a method like safe_render_code_from_store and it just renders all of code from the store.
  Same with chat, and all the bufnrs and winids are put into the store on open.
* Gracefully handle when ollama isn't installed or running
* Logging the errors instead of showing them in the window was the wrong way, I just want to handle as many as possible in the provider.

#### Bugs
* If you open the code window, get a buncha code in there, then switch to a file of a different filetype, then open again, the syntax highlighting is lost
* Sometimes, especially with openai, there are responses that don't conform to json, and responses where json is split between multiple. Both providers should handle that stuff more robustly.
