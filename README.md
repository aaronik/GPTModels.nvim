# LLM plugin for neovim

This plugin has two different windows designed to integrate LLM AI into your workflow.

* **Test first development** - This plugin focuses on clean, stable code. All features are well tested.
* **Developer UX in mind** - The goal is a simple, ergonomic interface. It's meant to be easy to pick up, not requiring any memorization. The tool "gets out of your way".

---

### This plugin offers two commands:

* `:GPTChat` - open a chat window, like ChatGPT
* `:GPTCode` - open a window designed to iterate on selections of code

---

### Features:

* **Background processing** - close the window while the AI responds, open the window and the response will be there.

### * Supports Ollama, OpenAI

* Kills request process when window is closed
* OR Finishes requests safely in background!

## TODO

* Use ctrl-w + hjkl to move between windows
* code needs C-y?
* Rename to something better than GPT. Models? TwoModel? Maybe GPT is good? AIModels?
* Make a readme fr
* Focus same buffer on nui exit?
* Prompt tests?
* Chat loading indicator?
* Add copilot support .. Very hard as it turns out
* Protect against opening windows many times?
* One really big integration flow for each window
* Figure out how to test nui border text and test all the titles
* If you open the code window, get a buncha code in there, then switch to a file of a different filetype, then open again, the syntax highlighting is lost
