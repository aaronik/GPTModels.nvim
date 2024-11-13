#### Little Things
* chat window's prompt needs to be adjusted so the user request counts as much as the included files,
  currently it's dominated by the files and many llms end up just explaining what's in the files
* Get live reloading of C-p telescope model picker when openai results come in
* chat window should auto scroll when opened with autosaved session
* code needs C-y?
* Focus same buffer on nui exit?
* Add copilot support
    * https://github.com/B00TK1D/copilot-api/blob/main/api.py -- python implementation
* Protect against opening windows many times?
* Figure out how to test nui border text and test all the titles
* Help window
    * with detailed descriptions of commands
    * input bottom border is just q, Enter, and Ctrl-h maybe, or maybe just Ctrl-h
* :help docs
* make target for project wide type check pass
    * https://luals.github.io/wiki/usage/#arguments
    * /opt/homebrew/Cellar/lua-language-server/3.11.1/bin/lua-language-server --checklevel=Warning --logpath=/tmp/lls_out --check lua/gptmodels
    The above prints the lls results into a json file. It does not recognize the neodev configured stuff though, so no vim global is configured, etc.
    and there are >200 errors for the fully working plugin.

* Switch to actual busted for testing, remove plenary if possible
    * Might could leverage lazy.nvim's built-in luarocks package management system

#### Big Ideas
* window for project wide patch actions, similar to aider
* window for nvim meta actions? The llm has control of the nvim environment?
