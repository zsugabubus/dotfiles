if exists(':ManKeyword')
	finish
endif

command! -bar -bang -nargs=+ ManKeyword
	\ silent execute 'Man '.join([<f-args>][:-2], ' ')|
	\ call search('^\v {3,}\zs<\V'.escape([<f-args>][-1], '\').'\>', 'w')

augroup mankey_ft
	autocmd!

	autocmd BufRead zathurarc setlocal keywordprg=:ManKeyword\ 5\ zathurarc
	autocmd FileType mbsyncrc setlocal keywordprg=:ManKeyword\ 1\ mbsync
	autocmd FileType muttrc   setlocal keywordprg=:ManKeyword\ 5\ muttrc
	autocmd FileType remind   setlocal keywordprg=:ManKeyword\ 1\ remind
	autocmd FileType tmux     setlocal keywordprg=:ManKeyword\ 1\ tmux
	autocmd FileType zsh      setlocal keywordprg=:ManKeyword\ 1\ zshall

augroup END
