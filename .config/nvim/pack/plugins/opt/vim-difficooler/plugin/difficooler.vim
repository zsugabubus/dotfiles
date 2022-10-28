if exists('#difficooler')
	finish
endif

augroup difficooler
	autocmd!

	autocmd TextChanged *
		\ if empty(&buftype)|
		\   diffupdate|
		\ endif

	" Quit from every diffed window; though quit is forbidden inside windo.
	autocmd! QuitPre *
		\ if &diff|
		\   execute 'windo if winnr() !=# '.winnr().' && &diff|quit|endif'|
		\ endif

	autocmd BufHidden *
		\ if !&buflisted|
		\   diffoff!|
		\ endif
	autocmd BufUnload *
		\ if &diff|
		\   diffoff!|
		\ endif

augroup END
