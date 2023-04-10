function! capture#Capture(arg) abort
	let output = execute(substitute(a:arg, '^$', 'messages', ''), 'silent')
	if empty(output)
		echohl WarningMsg
		echomsg "no output"
		echohl None
	else
		new
		setlocal buftype=nofile noswapfile
		let output = trim(l:output)
		put! =l:output
	endif
endfunction
