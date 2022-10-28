if exists('#vim_reload')
	finish
endif

augroup vim_reload
	autocmd!
	autocmd BufWritePost *colors/*.vim ++nested let &background = &background
	autocmd BufWritePost init.vim,vimrc ++nested source <afile>
augroup END
