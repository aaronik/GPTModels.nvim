# LLM plugin for neovim

### * Supports Ollama, OpenAI

* Kills request process when window is closed
* OR Finishes requests safely in background!

## TODO

* Use ctrl-w + hjkl to move between windows
* Defend against errant util.logs by handling error when the file doesn't exist
* code needs C-y and something to bring changes into left pane
* In the tests, there're some commented out vim.wait(20)s, masking invalid window errors. Fix'em
* Rename to something better than GPT. Models? TwoModel? Maybe GPT is good?
* Make a readme fr
* Error handling for ollama and openai providers
* Focus same buffer on nui exit?
* Prompt tests?
* Chat loading indicator?
* Add copilot support .. Very hard as it turns out
* Protect against opening windows many times?
* One really big integration flow for each window
* Figure out how to test nui border text and test all the titles
