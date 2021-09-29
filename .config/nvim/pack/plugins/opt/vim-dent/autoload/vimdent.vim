function! vimdent#Detect() abort
	if
		\ !empty(&buftype) ||
		\ 0 <=# index(split('help diff', ' '), &filetype)
		return
	endif

	if &verbose
		command! -nargs=+ -buffer VimdentDebug echomsg 'vimdent:' <args>
	else
		command! -nargs=+ -buffer VimdentDebug
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
			let context = level
			VimdentDebug printf('(%d) sw=%d ts=%d et=%d from %s', context, &sw, &ts, &et, bufname(other))
			if context ==# 2
				break
			endif
		endif
	endfor

	let ts = &tabstop
	try
		setlocal ts=100

		let indents = {}
		let prev_tab = 0
		let prev_sp = 0
		for lnum in range(1, min([line('$'), 5000]))
			let indent = indent(lnum)
			let tab = indent / 100
			let space = indent % 100
			let d = (tab - prev_tab).','.(space - prev_sp)
			let indents[d] = get(indents, d, 0) + 1
			let prev_tab = tab
			let prev_sp = space
		endfor
	finally
		let &tabstop = ts
	endtry

	" Filter out:
	" - No changes.
	" - Multiple tab changes.
	call filter(indents, {d,n->
		\ d !=# '0,0' &&
		\ abs(matchstr(d, '.*\ze,')) <=# 1
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

	if &verbose
		VimdentDebug 'tabs,spaces' 'count'
		for [d, n] in items(indents)
			VimdentDebug d n
		endfor
		VimdentDebug 'spaces:' spaces 'vs' 'tabs:' tabs
	endif

	let max_spaces = max(spaces)
	if max_spaces <=# tabs && 0 <# tabs
		" Use default &ts.
		" Use tabs.
		setlocal noexpandtab
		" No spaces so same as a tab.
		setlocal shiftwidth=0 softtabstop=0
		VimdentDebug 'ts=default'
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

		if &verbose
			VimdentDebug 'shifts:' string(spaces)
		endif

		let ts = ts_minus_sw + &shiftwidth

		" &sw known but file has no tabs in it so unable to determine &ts. However
		" when a file found with set and compatible &sw and &ts we can use those
		" values.
		if context ==# 2 && !(&tabstop % &shiftwidth)
			VimdentDebug printf('sw=%d ts=%d sts=%d (inherited)', &sw, &ts, &sts)
		" Other &sw, &ts pairings are (likely) junk.
		elseif
			\ &shiftwidth * 2 == ts ||
			\ &shiftwidth * 4 == ts
			setlocal noexpandtab
			let &tabstop = ts
			let &softtabstop = &tabstop
			VimdentDebug printf('sw=%d ts=sts=%d et=%d', &sw, &ts, &et)
		else
			setlocal expandtab
			let &tabstop = &shiftwidth
			let &softtabstop = &tabstop
			VimdentDebug printf('sw=ts=sts=%d et=%d', &sw, &et)
		endif
	else
		VimdentDebug 'all=default'
	endif

	delcommand! VimdentDebug
endfunction
