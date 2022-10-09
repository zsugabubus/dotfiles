function! pastereindent#paste(p) abort
	if !(!&paste && (getregtype(v:register) ==# 'V' ||
	\               (getregtype(v:register) ==# 'v' && empty(getline('.')))))
		return a:p
	endif

	let reg = getreg(v:register)
	let cur_indent = indent('.')
	if cur_indent <=# 0
		let cur_indent = indent(call(a:p ==# 'p' ? 'prevnonblank' : 'nextnonblank', ['.']))
	endif
	return a:p.':call pastereindent#paste_reindent('.(len(split(reg, "\n", 1)) - (getregtype(v:register) ==# 'V')).','.cur_indent.")\<CR>"
endfunction

function! pastereindent#paste_reindent(nlines, cur_indent) abort
	let v:lnum = nextnonblank('.')
	if !empty(&indentexpr)
		let save_cursor = getcurpos()
		" meson.vim is fucked like hell.
		"
		" We need silent! because some brainfucked people put echom inside
		" indentexptr and someone other reviewed it and thought its okay.
		"
		" try...catch also needed just because. Why not? meson.vim shits into the
		" fan, but forgets catching it.
		try
			silent! sandbox let indent = eval(&indentexpr)
		catch
			let indent = 0
		finally
			call setpos('.', save_cursor)
		endtry
	elseif &cindent
		let indent = cindent(v:lnum)
	elseif &lisp
		let indent = lispindent(v:lnum)
	else
		return
	endif

	if indent <=# 0
		let indent = a:cur_indent
	endif

	let indent = (indent - indent(v:lnum)) / shiftwidth()

	execute 'silent! normal!' repeat(a:nlines.(indent < 0 ? '<<' : '>>'), abs(indent))
	normal! _
endfunction
