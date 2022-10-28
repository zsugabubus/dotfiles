function! wtf#search(forward) abort
	let search = getcharsearch()
	let mode = mode(1)
	let isvisual = mode =~# "\\m\\C^[vV\<C-V>]$"
	let c = escape(search.char, '\')
	let lnum = line('.')
	" Where to position cursor.
	let e = (-!!search.until + (mode ==# 'n' ? 0 : isvisual ? &selection !=# 'inclusive' : 1)) * (search.forward ==# a:forward ? 1 : -1)
	let pat = (search.char =~# '\m\l'
		\ ? '\v\C%(%('.(e ==# -1 ? '\ze\_.' : '').'<|'.(e ==# -1 ? '\ze' : '').'[_0-9])\V\['.tolower(c).toupper(c).']'
			\ .'\v|'.(e ==# -1 ? '\ze' : '').'[a-z_]\V'.toupper(c)
			\ .'\v|\V'.toupper(c).'\v[a-z]@=)'
		\ : '\c'.(e ==# -1 ? '\ze\_.' : '').'\V'.c).(e ==# 1 ? '\_.\ze' : '')
	let flags = 'eW'.(search.forward ==# a:forward ? 'z' : 'b')

	for _ in range(1, v:count1)
		call search(pat, flags)
	endfor
endfunction
