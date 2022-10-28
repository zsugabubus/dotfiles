if exists('#betterm')
	finish
endif

augroup betterm
	autocmd!
	autocmd TermOpen * call betterm#setup()
	autocmd TermClose * stopinsert
augroup END

tnoremap <C-v> <C-\><C-n>
