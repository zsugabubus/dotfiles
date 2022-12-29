function! bufgrep#BufGrep(pattern, add) abort
	let tmpfile = tempname()
	try
		doautocmd QuickFixCmdPre vimgrep //j <buffers>
		if !a:add
			call setqflist([])
		endif

		for buf in getbufinfo({'buflisted': 1})
			if !empty(getbufvar(buf.bufnr, '&buftype'))
				continue
			endif

			if buf.changed
				let grepfile = tmpfile
				call writefile(getbufline(buf.bufnr, 1, '$'), grepfile)
			else
				let grepfile = bufname(buf.bufnr)
				if grepfile ==# ''
					continue
				endif
			endif
			try
				noautocmd silent execute 'vimgrepadd' '/'.escape(a:pattern, '/').'/jg' fnameescape(grepfile)
			catch 'No match:'
				continue
			endtry
			let grepbuf = bufnr(grepfile)
			if grepbuf ==# buf.bufnr
				continue
			endif

			let items = getqflist()
			for item in items
				if item.bufnr ==# grepbuf
					let item.bufnr = buf.bufnr
				endif
			endfor
			call setqflist(items, 'r')
		endfor

		doautocmd QuickFixCmdPost
	finally
		noautocmd silent! execute 'bwipeout' tmpfile
		call delete(tmpfile)
	endtry
endfunction
