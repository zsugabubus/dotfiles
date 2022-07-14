" Make / fuzzy.
silent! nnoremap <silent><unique> <Plug>(FuzzySearchFZF) :<C-u>call fuzzysearch#search('fzf')<CR>
silent! nnoremap <silent><unique> <Plug>(FuzzySearchFizzy) :<C-u>call fuzzysearch#search('fizzy')<CR>
