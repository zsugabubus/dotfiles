function! qf#file(globs, bang) abort
	let pats = map(a:globs, {_, glob-> glob2regpat(glob)})
	let items = []
	for item in getqflist()
		let ok = item.bufnr ==# 0

		if !ok
			let matched = 0
			let name = bufname(item.bufnr)
			for pat in pats
				if name =~ pat
					let matched = 1
					break
				endif
			endfor
			let ok = matched !=# a:bang
		endif

		if ok
			call add(items, item)
		endif
	endfor
	call setqflist(items)
endfunction

function! qf#global(pat, bang) abort
	let pat = a:pat
	if pat ==# ''
		let pat = @/
	endif
	call setqflist(getqflist()->filter({_, item-> !item.valid || (item.text =~ pat) !=# a:bang}))
endfunction

function! qf#n(nth, bang) abort
	let nth = str2nr(a:nth)
	if nth == 0
		let nth = 1
	endif
	let items = []
	let keys = {}
	for item in getqflist()
		let key = bufname(item.bufnr) . ':' . item.lnum
		let keys[key] = get(keys, key, 0) + 1
		let ok = !item.valid || (keys[key] == nth) != a:bang
		if ok
			call add(items, item)
		endif
	endfor
	call setqflist(items)
endfunction

function! qf#buflisted() abort
	for item in getqflist()
		if 0 < item.bufnr
			call setbufvar(item.bufnr, '&buflisted', 1)
		endif
	endfor
endfunction
