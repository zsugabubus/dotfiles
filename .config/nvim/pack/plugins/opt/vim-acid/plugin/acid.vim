function! s:acd()
	return haslocaldir() ? 'lcd' : haslocaldir(-1) ? 'tcd' : 'cd'
endfunction

cnoreabbrev <expr> cd getcmdtype() ==# ':' && getcmdpos() ==# 3 ? <SID>acd() : 'cd'
cnoreabbrev <expr> ccd getcmdtype() ==# ':' && getcmdpos() ==# 4 ? <SID>acd().' %:p:h' : 'ccd'
