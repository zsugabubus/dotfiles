function! sweep#Sweep() abort
	for buf in range(1, bufnr('$'))
		if buflisted(buf)
			silent! execute 'bdelete' buf
		endif
	endfor
endfunction
