if has('nvim')
	lua require 'vimdent'
endif

function! s:dictmax(dict) abort
	let max = max(a:dict)
	for [k, v] in items(a:dict)
		if v ==# max
			return [k, v]
		endif
	endfor
	return [0, 0]
endfunction

function! vimdent#Detect(...) abort
	if
		\ !empty(&buftype) ||
		\ &filetype =~? 'help\|diff\|git'
		return
	endif

	let context = 0

	let start = reltime()

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

	let saved_ts = &tabstop
	try
		noautocmd setlocal ts=100

		let max_lines = 5000
		if has('nvim')
			let indents = luaeval("_VimdentGetIndents(_A)", max_lines)
		else
			" Welcome to VimL that carefully reads even your comments. This loop is
			" so hot that compressing names results in ms of speedup. And for
			" millions of users times millions of files...

			" Space after tab is ignored when it is determined to be used for
			" aligment purposes. They shall not be relied on to detect &sw.

			let I = {} " indents
			let T = 0 " prev_tabs
			let S = 0 " prev_spaces
			for l in range(1, min([line('$'), max_lines]))
let i=indent(l)
let t=i/100
let s=0<t&&t==T&&(!S||!(i%100))?0:i%100
let d=(t-T).','.(s-S)
let I[d]=get(I,d,0)+1
let T=t
let S=s
			endfor
			let indents = I
		endif
	finally
		noautocmd let &tabstop = saved_ts
	endtry

	echomsg 'raw indents:' indents

	" Find out most common kind of change. Tab or space?
	let ntabs = 0
	let spaces = {}
	let items = items(indents)
	let indents = {}
	for [d, n] in items
		let [tab, space] = split(d, ',')
		let [tab, space] = [+tab, +space]

		" Filter out:
		" - No changes.
		" - Single space changes.
		if tab ==# 0 && abs(space) <=# 1
			continue
		end

		" Count spaces when there is no tab change.
		if tab ==# 0
			let spaces[abs(space)] = get(spaces, abs(space), 0) + n
		endif

		" Count tabs when there is no space change.
		if space ==# 0
			let ntabs += n
		endif

		let key = tab.','.space
		let indents[key] = get(indents, key, 0) + n
	endfor

	let [max_dspace, max_nspaces] = s:dictmax(spaces)

	echomsg 'indents:' indents
	echomsg 'spaces:' spaces '->' [max_dspace, max_nspaces] 'vs' 'tabs:' ntabs

	if max_nspaces <=# ntabs && 0 <# ntabs
		" No subsequent lines have space changes thus &sw cannot not be determined
		" for sure. However we can try guess it in cases when tabs became space
		" (e.g. incorrectly set &et) so we can use this formula to attempt to fix
		" it: `tabs (+-1 indentation) == spaces`.
		if max_nspaces ==# 0
			let spaces = { '2': 0, '4': 0, '8': 0 }
			for [d, n] in items(indents)
				let [tab, space] = split(d, ',')
				if 1 <# abs(tab) && 0 <# space
					for sw in keys(spaces)
						if
							\ -space == (tab - 1) * sw ||
							\ -space == (tab    ) * sw ||
							\ -space == (tab + 1) * sw
							let spaces[sw] += n
						end
					endfor
				endif
			endfor

			let [max_dspace, max_nspaces] = s:dictmax(spaces)
			echomsg 'tab spaces:' spaces '->' [max_dspace, max_nspaces]
		endif

		" Use tabs.
		setlocal noexpandtab
		if max_nspaces ==# 0
			" Use default &ts.
			" No spaces so same as a tab.
			setlocal shiftwidth=0 softtabstop=-1
			echomsg 'sts=sw=ts ts=default et=0'
		else
			let &tabstop = max_dspace
			let &shiftwidth = max_dspace
			let &softtabstop = max_dspace
			echomsg printf('sw=ts=sts=%d et=0', max_dspace)
		endif
	elseif 0 <# max_nspaces
		let &shiftwidth = max_dspace

		" &sw is known, now found out whether tabs were used.

		" Summarize cases when tab becomes space and vice versa.
		let spaces = {}
		let ts_minus_sw = 0
		let max = 0
		for [d, n] in items(indents)
			let [tab, space] = split(d, ',')
			if abs(tab) !=# 1
				continue
			endif
			let space = +tab * -space
			if 0 <# space
				let n += get(spaces, space, 0)
				let spaces[space] = n
				if max <=# n
					let max = n
					let ts_minus_sw = space
				endif
			endif
		endfor

		echomsg 'shifts:' spaces '->' ts_minus_sw '+' max_dspace

		let ts = ts_minus_sw + &shiftwidth

		" &sw known but file has no tabs in it so unable to determine &ts. However
		" when a file found with set and compatible &sw and &ts we can use those
		" values.
		if context ==# 2 && !(&tabstop % &shiftwidth)
			echomsg printf('sw=%d', &sw)
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
	echomsg 'total' (reltimefloat(reltime(start)) * 1000) 'ms'
endfunction
