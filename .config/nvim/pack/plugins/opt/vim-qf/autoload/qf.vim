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
	call setqflist(getqflist()->filter({_, item-> !item.valid || (item.text =~ a:pat) !=# a:bang}))
endfunction
