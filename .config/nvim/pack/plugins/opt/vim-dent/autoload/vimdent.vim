if has('nvim')
	lua require 'vimdent'
endif

function! vimdent#Detect(...) abort
	if
		\ !empty(&buftype) ||
		\ &filetype =~? 'help\|diff\|git'
		return
	endif

	let context = 0

	let bufnr = bufnr()
	let dirname = fnamemodify(bufname(bufnr), ':h')
	for other in range(1, bufnr('$'))
		if
			\ !bufexists(other) ||
			\ !empty(getbufvar(other, '&buftype')) ||
			\ other ==# bufnr
			continue
		endif

		let sw = getbufvar(other, '&shiftwidth')
		let ts = getbufvar(other, '&tabstop')

		" Level of specificity.
		let level = !!sw + (sw <# ts)

		if
			\ context < level &&
			\ dirname ==# fnamemodify(bufname(other), ':h') &&
			\ &filetype ==# getbufvar(other, '&filetype')
			let &shiftwidth = sw
			let &tabstop = ts
			let &expandtab = getbufvar(other, '&expandtab')
			let &softtabstop = getbufvar(other, '&softtabstop')

			echomsg printf('(%d) sw=%d ts=%d et=%d from %s', level, &sw, &ts, &et, bufname(other))

			let context = level
			if context ==# 2
				break
			endif
		endif
	endfor

	let ts = &tabstop
	try
		noautocmd setlocal ts=100

		let max_lines = 5000
		if has('nvim')
			let indents = luaeval("_VimdentGetIndents(_A)", max_lines)
		else
			" Welcome to Vim that carefully reads even your comments. This loop is
			" so hot that compressing names results in ms of speedup. And for
			" millions of users times millions of files...

			let I = {} " indents
			let T = 0 " prev_tabs
			let S = 0 " prev_spaces
			for l in range(1, min([line('$'), max_lines]))
let i=indent(l)
let t=i/100
let s=i%100
let d=(t-T).','.(s-S)
let I[d]=get(I,d,0)+1
let T=t
let S=s
			endfor
			let indents = I
		endif
	finally
		noautocmd let &tabstop = ts
	endtry

	" Filter out:
	" - No changes.
	" - Multiple tab changes.
	" - Single space changes.
	call filter(indents, {d,n->
		\ d !=# '0,0' &&
		\ abs(matchstr(d, '.*\ze,')) <=# 1 &&
		\ abs(matchstr(d, ',\zs.*')) !=# 1
		\})

	" Find out most common kind change. Tab or space?
	let tabs = 0
	let spaces = {}
	for [d, n] in items(indents)
		" Count spaces when there is no tab change.
		if d[:1] == '0,'
			let space = abs(+matchstr(d, ',\zs.*'))
			let spaces[space] = get(spaces, space, 0) + n
		endif

		" Count tabs when there is no space change.
		if d[-2:] == ',0'
			let tabs += n
		endif
	endfor

	echomsg 'indents:' indents
	echomsg 'spaces:' spaces 'vs' 'tabs:' tabs

	let max_spaces = max(spaces)
	if max_spaces <=# tabs && 0 <# tabs
		" Use default &ts.
		" Use tabs.
		setlocal noexpandtab
		" No spaces so same as a tab.
		setlocal shiftwidth=0 softtabstop=0
		echomsg 'ts=default'
	elseif 0 <# max_spaces
		for [d, n] in items(spaces)
			if n ==# max_spaces
				let space = d
				break
			endif
		endfor

		let &shiftwidth = space

		" &sw is known, now found out whether tabs were used.

		" Summarize cases when tab becomes space and vica versa.
		let spaces = {}
		let ts_minus_sw = 0
		let max = -1
		for [d, n] in items(indents)
			let space = +matchstr(d, '.*\ze,') * -matchstr(d, ',\zs.*')
			if 0 <# space
				let n += get(spaces, space, 0)
				let spaces[space] = n
				if max <=# n
					let max = n
					let ts_minus_sw = space
				endif
			endif
		endfor

		echomsg 'shifts:' spaces

		let ts = ts_minus_sw + &shiftwidth

		" &sw known but file has no tabs in it so unable to determine &ts. However
		" when a file found with set and compatible &sw and &ts we can use those
		" values.
		if context ==# 2 && !(&tabstop % &shiftwidth)
			echomsg printf('sw=%d ts=%d sts=%d (inherited)', &sw, &ts, &sts)
		" Other &sw, &ts pairings are (likely) junk.
		elseif
			\ &shiftwidth * 2 == ts ||
			\ &shiftwidth * 4 == ts
			setlocal noexpandtab
			let &tabstop = ts
			let &softtabstop = &tabstop
			echomsg printf('sw=%d ts=sts=%d et=%d', &sw, &ts, &et)
		else
			setlocal expandtab
			let &tabstop = &shiftwidth
			let &softtabstop = &tabstop
			echomsg printf('sw=ts=sts=%d et=%d', &sw, &et)
		endif
	else
		echomsg 'all=default'
	endif
endfunction
