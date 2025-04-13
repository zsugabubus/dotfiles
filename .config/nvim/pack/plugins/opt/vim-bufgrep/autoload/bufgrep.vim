function! bufgrep#BufGrep(pattern, add) abort
	let tmpfile = tempname()
	let snail = @/
	try
		doautocmd QuickFixCmdPre vimgrep //j <buffers>

		if !a:add
			call setqflist([])
		endif

		if !empty(a:pattern)
			let @/ = a:pattern
		endif

		for info in getbufinfo({'buflisted': 1})
			let bufnr = info.bufnr

			if !empty(getbufvar(bufnr, '&buftype'))
				continue
			endif

			if info.changed
				let grepfile = tmpfile
				call writefile(getbufline(bufnr, 1, '$'), grepfile)
			else
				let grepfile = bufname(bufnr)
				if grepfile ==# ''
					continue
				endif
			endif

			try
				noautocmd silent execute 'vimgrepadd' '//jg' fnameescape(grepfile)
			catch 'No match'
				continue
			endtry

			" If vimgrepadd used a temporary file we have to map bufnrs of the newly
			" added items to refer to the original file.
			let grepbuf = bufnr(grepfile)
			if grepbuf ==# bufnr
				continue
			endif

			let items = getqflist()
			for item in items
				if item.bufnr ==# grepbuf
					let item.bufnr = bufnr
				endif
			endfor
			call setqflist(items, 'r')
		endfor

		doautocmd QuickFixCmdPost
	finally
		noautocmd silent! execute 'bwipeout' tmpfile
		call delete(tmpfile)
		let @/ = snail
	endtry
endfunction
