function! betterm#setup() abort
	nmap <buffer> <Return> gf

	let b:passthrough = {}
	for x in [
	\  ['<C-d>', 'd'],
	\  ['<C-u>', 'u']
	\]
		execute call('printf', ["nnoremap <silent><nowait><buffer> %s :call ! betterm#passthrough('less', '%s')<CR>"] + x)
	endfor

	startinsert
endfunction

function! betterm#passthrough(cmd, keys) abort
	if get(b:passthrough, a:cmd, -1) <# 0
		let pid = matchstr(bufname(), '\vterm://.{-}//\zs\d+\ze:')
		let children = systemlist(['ps', '--no-headers', '-o', 'cmd', '-g', pid])
		let b:passthrough[a:cmd] = 0 <=# match(children, '/'.a:cmd.'$')
	endif

	if !b:passthrough[a:cmd]
		return
	endif

	call feedkeys('a'.a:keys."\<C-\>\<C-n>:\<C-r>=line('w0')+".(line('.') - line('w0'))."\<CR>\<CR>", 'nit')
endfunction
