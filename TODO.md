* code needs C-y?
* Focus same buffer on nui exit?
* Add copilot support .. Very hard as it turns out
    * https://github.com/B00TK1D/copilot-api/blob/main/api.py -- python implementation
* Protect against opening windows many times?
* Figure out how to test nui border text and test all the titles
* Help window
    * with detailed descriptions of commands
    * input bottom border is just q, Enter, and Ctrl-h maybe, or maybe just Ctrl-h
* :help docs
* Model showing / hiding
    * Show all openai models?
    * Remove openai models when OPENAI_API_KEY is not set
        * Render in the chat/right window, at the top above all else, that this is happening?
    * Remove all ollama models when ollama.fetch_models fails indicating server isn't running?
        * Or is it better to alert that the server isn't running? Or both?


