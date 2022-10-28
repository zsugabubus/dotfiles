if exists('#themember')
	finish
endif

let s:theme = stdpath('config').'/theme.vim'

function! s:reload() abort
	try
		execute 'source' fnameescape(s:theme)
		let background = &background
		doautocmd Colorscheme
	catch
	endtry
endfunction

augroup themember
	autocmd!
	autocmd OptionSet background
		\ call writefile([printf('set background=%s', &background)], s:theme)|
		\ call system(['/usr/bin/pkill', '--signal', 'SIGUSR1', has('nvim') ? 'nvim' : 'vim'])
	autocmd Signal SIGUSR1 call s:reload()|redraw!
augroup END

call s:reload()
