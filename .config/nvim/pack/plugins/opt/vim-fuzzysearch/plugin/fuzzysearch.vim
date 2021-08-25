" Make / fuzzy.
silent! nnoremap <silent><unique> <Plug>(FuzzySearch) :<C-u>call fuzzysearch#search()<CR>
silent! nnoremap <silent><unique> <Plug>(FuzzySearchFZF) :<C-u>call fuzzysearch#search('fzf')<CR>

silent! nmap <silent><unique> z/ <Plug>(FuzzySearch)
