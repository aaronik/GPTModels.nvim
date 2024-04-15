function! GPT()
  lua require('gpt').run()
endfunction
command! GPT call GPT()

