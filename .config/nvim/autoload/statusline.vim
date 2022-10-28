function! statusline#tabline() abort
	let tabs = ''
	let curtabnr = tabpagenr()
	for tabnr in range(1, tabpagenr('$'))
		let bufnrs = tabpagebuflist(tabnr)
		let winnr = tabpagewinnr(tabnr)
		let bufnr = bufnrs[winnr - 1]

		let tabpath = bufname(bufnr)
		let tabname = '[No Name]'
		if !empty(tabpath)
			let tabname = matchstr(tabpath, '\v([^/]*/)?[^/]*$')
		endif

		let tab = tabnr.':'.tabname

		if getbufvar(bufnr, '&modified')
			let tab .= ' [+]'
		else
			for bufnr in bufnrs
				if getbufvar(bufnr, '&modified')
					let tab .= ' +'
					break
				endif
			endfor
		endif

		let tabs .= '%'.tabnr.'T%#TabLine'.(tabnr == curtabnr ? 'Sel' : '').'# '.tab.' '
	endfor
	return tabs.'%#TabLineFill#%T'
endfunction
