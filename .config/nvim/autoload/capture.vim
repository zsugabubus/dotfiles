function! capture#Capture(arg) abort
	let output = execute(substitute(a:arg, '^$', 'messages', ''), 'silent')
	if empty(output)
		echohl WarningMsg
		echomsg "no output"
		echohl None
	else
		new
		setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
		let output = trim(l:output)
		put! =l:output
	endif
endfunction
