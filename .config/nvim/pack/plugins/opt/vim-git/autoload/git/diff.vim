function! git#diff#open(...) abort range
	let rev = get(a:000, 0, ':0')
	" ::./file -> :./file
	if rev ==# ':'
		let rev = ''
	endif
	diffthis
	execute 'vsplit git://'.fnameescape(rev).':./'.fnamemodify(fnameescape(expand('%')), ':.')
	setlocal bufhidden=wipe
	autocmd BufUnload <buffer> diffoff
	diffthis
	wincmd p
	wincmd L
endfunction
