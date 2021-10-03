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
	let voffsets = {}
	let cmd = ''

	" If 0, align all columns.
	if !g:mall_count
		let g:mall_count = 9999
	endif

	" Collecting column positions for aligning.
	for lnum in range(line("'<"), line("'>"))
		let syntax = s:get_syntax_type(lnum, 1)
		let lines[lnum] = []
		let voffsets[lnum] = 0
		let from_vcol = 1
		let from_col = 1
		let col = 1
		let line = getline(lnum)
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

			let segment = strpart(line, from_col - 1, col - from_col)

			let vcol = virtcol("']")
			call add(lines[lnum], [segment, from_vcol, vcol])
			let [from_col, from_vcol] = [col, vcol]
		endwhile
	endfor

	let pat = '\V'.escape(fillchar, '\').'\*\v$'

	let index = 0
	while 1
		" The virtcol columns should be aligned to.
		let align_to = 0

		let any = 0
		for [lnum, columns] in items(lines)
			" No more columns for this line.
			if len(columns) <=# index
				continue
			endif

			let any = 1
			let column = columns[index]
			let segment = column[0]
			let start = column[1] + voffsets[lnum]
			let vcol = start + strdisplaywidth(strpart(segment, 0, match(segment, pat)), start - 1)
			let align_to = max([align_to, vcol])
		endfor

		" No more columns to align.
		if !any
			break
		endif

		for [lnum, columns] in items(lines)
			if len(columns) <=# index
				continue
			endif

			let column = columns[index]
			let end_vcol = column[2] + voffsets[lnum]
			if end_vcol <# align_to
				let cmd .= lnum.'G'.end_vcol.'|'.(align_to - end_vcol).'i'.fillchar."\<Esc>"
			elseif align_to <# end_vcol
				let cmd .= lnum.'G'.end_vcol.'|d'.align_to.'|'
			endif
			let voffsets[lnum] += align_to - end_vcol
		endfor

		let index += 1
	endwhile

	noautocmd silent! execute "normal! " cmd "\<CR>"
endfunction

function! mall#align(mode) abort
	let view = winsaveview()
	set opfunc=<SID>noop

	let [saved_ws, saved_ve] = [&ws, &ve]
	try
		set nowrapscan virtualedit=all
		call s:do_align()
	finally
		set opfunc=mall#align
		let [&ws, &ve] = [saved_ws, saved_ve]
		call winrestview(view)
	endtry
endfunction
