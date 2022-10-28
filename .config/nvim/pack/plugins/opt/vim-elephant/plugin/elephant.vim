if exists('#restorecursor')
	finish
endif

augroup restorecursor
	autocmd! BufReadPost * autocmd FileType <buffer> ++once autocmd BufEnter <buffer> ++once
		\ if 1 <= line("'\"") && line("'\"") <= line("$") && &filetype !~? '\vgit|commit|mail'|
		\   execute 'normal! g`"zvzz'|
		\ endif
augroup END

augroup savesession
	autocmd! VimLeave *
		\ if 0 ==# v:dying && 0 ==# v:exiting && !empty(v:this_session)|
		\   execute 'mksession!' v:this_session|
		\ endif
augroup END

command! SS source Session.vim
