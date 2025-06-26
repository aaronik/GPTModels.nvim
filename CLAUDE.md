# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

**Testing:**
- `make test` - Run full test suite with Plenary
- `make test-watch` - Continuous testing with nodemon for development
- Single test: `nvim --headless -c "PlenaryBustedFile tests/path/to/spec.lua"`

**Code Quality:**
- `make check` - Run Luacheck static analysis
- `make fmt` - Format code with StyLua
- `make pass` - Run all quality checks (test + check + fmt)

**Development:**
- Set `GPTMODELS_NVIM_ENV=development` for hot-reload during development
- Use `make test-watch` for TDD workflow

## Architecture Overview

GPTModels.nvim is a window-based AI plugin with a layered, modular architecture:

### Core Components
- **`llm.lua`**: Universal LLM abstraction layer that routes to providers
- **`store.lua`**: Singleton state management for models, chat history, and session data
- **`cmd.lua`**: Async job execution using `vim.uv` for streaming responses
- **`providers/`**: OpenAI and Ollama implementations behind common interface
- **`windows/`**: NUI.nvim-based UI components (chat, code, common utilities)

### Plugin Entry Points
- **`plugin/init.lua`**: Creates user commands, handles visual mode detection
- **`lua/gptmodels/init.lua`**: Main interface with `code()` and `chat()` functions

### Window System
Two main interfaces built on NUI.nvim:
- **Code window** (`:GPTModelsCode`): Split-pane for code iteration with original/response/prompt views
- **Chat window** (`:GPTModelsChat`): Conversation interface with message history

## Key Patterns

**Provider Pattern**: `llm.lua` delegates to specific providers based on current model selection

**State Management**: `Store` singleton maintains session state across window operations

**Async-First**: Built around Neovim's async capabilities with streaming response handling

**Test-Driven**: Comprehensive test coverage with `spec_helpers.lua` providing mocking and state reset

## Development Notes

- **Type System**: Extensive Lua type annotations in `types.lua` for IDE support
- **Zero Config**: Works out of the box, optional setup in user config
- **Dependencies**: Requires `nui.nvim`, `telescope.nvim`, and `curl`
- **Environment**: Set `OPENAI_API_KEY` for OpenAI, requires local Ollama server for Ollama provider
- **Visual Selection**: Commands automatically detect and handle visual mode selections
- **Background Processing**: Windows can close while maintaining streaming responses

## Debugging and Introspection

**Current Model Detection**: To programmatically determine which model is currently selected (useful when chat/code windows are open):
```lua
lua local store = require('gptmodels.store'); local model = store:get_model(); print('Current model: ' .. model.provider .. '.' .. model.model)
```

This accesses the Store singleton's state and returns the currently active provider and model. The result matches what's displayed in NUI window border titles like "Chat w/ openai.gpt-4o" or "Code w/ ollama.llama3.1:latest".

**When Quitting Nvim**:
