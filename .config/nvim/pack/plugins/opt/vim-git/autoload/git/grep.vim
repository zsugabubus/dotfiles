function! git#grep#do(cmdline) abort
	let saved = &l:grepprg
	try
		let &l:grepprg = 'git grep'
		execute a:cmdline
		redraw " Avoid hit ENTER prompt.
	finally
		let &l:grepprg = saved
	endtry
endfunction
