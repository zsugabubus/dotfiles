function! s:noop(mode) abort
	" An empty operator function that just needed to execute supplied motion
	" multiple times.
endfunction

" Aligning happens only in text with matching syntax type.
function s:get_syntax_type(lnum, col) abort
	return synIDattr(synIDtrans(synID(a:lnum, a:col, 1)), "name") =~? '\vcomment|string'
endfunction

function s:do_align() abort
	let fillchar = ' '
	let lines = {}
	let offs = {}
	let cmd = ''

	" If 0, align all columns.
	if !g:mall_count
		let g:mall_count = 9999
	endif

	" Collecting column positions for aligning.
	for lnum in range(line("'<"), line("'>"))
		let syntax = s:get_syntax_type(lnum, 1)
		let lines[lnum] = []
		let offs[lnum] = 0
		let oldvcol = 1
		let oldcol = 1
		let col = 1
		while len(lines[lnum]) <# g:mall_count
			call cursor(lnum, col)
			if col('.') !=# col
				break
			endif

			let ok = 0
			noautocmd silent! execute "normal! .:let ok = 1\<CR>"

			" Error while moving.
			if !ok
				break
			endif

			let [olnum, ocol] = [line("']"), col("']")]
			" Moved over line.
			if olnum !=# lnum || ocol <# col
				break
			endif
			" Stayed in place.
			if ocol ==# col
				let col += 1
				continue
			endif
			let col = ocol

			if syntax !=# s:get_syntax_type(lnum, col)
				continue
			endif

			let line = strpart(getline(lnum), oldcol - 1, col - oldcol)

			let vcol = virtcol("']")
			call add(lines[lnum], [line, oldvcol, vcol])
			let [oldcol, oldvcol] = [col, vcol]
		endwhile
	endfor

	let pat = '\v^.{-}\zs\V'.escape(fillchar, '\').'\*\v$'

	let index = 0
	let oldwall = 1
	while 1
		" The virtcol columns should be aligned to.
		let wall = 0

		let any = 0
		for [lnum, columns] in items(lines)
			" No more columns for this line.
			if len(columns) <=# index
				continue
			endif

			let any = 1
			let column = columns[index]
			let segment = column[0]
			let start = column[1] + offs[lnum]
			let vcol = start + strdisplaywidth(strpart(segment, 0, match(segment, pat)), start)
			" echom start '+' strpart(segment, 0, match(segment, pat)) '->' vcol
			let wall = max([wall, vcol])
		endfor

		" No more columns to align.
		if !any
			break
		endif

		" echom 'max width='.wall
		" echom lines

		for [lnum, columns] in items(lines)
			if len(columns) <=# index
				continue
			endif
			let column = columns[index]
			let endvcol = column[2] + offs[lnum]
			if endvcol <# wall
				let cmd .= lnum.'G'.endvcol.'|'.(wall - endvcol).'i'.fillchar."\<Esc>"
			elseif wall <# endvcol
				let cmd .= lnum.'G'.endvcol.'|d'.wall.'|'
			endif
			let offs[lnum] += wall - endvcol
		endfor

		let index += 1
	endwhile

	noautocmd silent! execute "normal! " cmd "\<CR>"
endfunction

function! mall#align(mode) abort
	let view = winsaveview()
	set opfunc=<SID>noop

	let [oldws, oldve] = [&ws, &ve]
	try
		set nowrapscan virtualedit=all
		call s:do_align()
	finally
		set opfunc=mall#align
		let [&ws, &ve] = [oldws, oldve]
		call winrestview(view)
	endtry
endfunction
