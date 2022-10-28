command! Make call make#make()

augroup make_qf
	autocmd! QuickFixCmdPost [^l]* ++nested call make#qf()
augroup END

augroup make_errorformat
	autocmd!
	function! s:errorformat_make() abort
		if 'make' == &makeprg|
			set errorformat^=make:\ %*[[]%f:%l:\ %m
			set errorformat^=make%.%#:\ ***\ %*[[]%f:%l:\ %.%#]\ Error\ %n
			set errorformat^=make%.%#:\ ***\ %*[[]%f:%l:\ %m
			set errorformat^=/usr/bin/ld:\ %f:%l:\ %m
		endif
	endfunction
	autocmd VimEnter * call s:errorformat_make()
	autocmd OptionSet makeprg call s:errorformat_make()
augroup END
