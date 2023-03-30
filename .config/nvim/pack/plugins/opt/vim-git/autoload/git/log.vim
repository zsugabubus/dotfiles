function! git#log#open(firstlin, lastlin, range, cmd) abort
	let cmd = a:cmd

	if a:range >= 1
		let cmd += [printf('-L%s,%s:%s', a:firstlin, a:range == 2 ? a:lastlin : '', expand('%'))]
	endif

	if empty(cmd)
		enew
		call termopen(['git', 'log-vim'] + cmd)
	else
		vertical new
		call git#buf#read(['log'] + cmd)
	endif
endfunction
