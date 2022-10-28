function! make#make() abort
	let start = strftime('%s')
	echon "\U1f6a7  Building...  \U1f6a7"
	call s:guess_makeprg()
	if 0 <=# stridx(&l:makeprg, '$*')
		make build
	else
		make
	endif
	call s:bell()
	redraw
	let errors = 0
	let warnings = 0
	for item in getqflist()
		if item.text =~? ' error:\? ' || item.type ==# 'E'
			let errors += 1
		elseif item.text =~? ' warning:\? ' || item.type ==# 'W'
			let warnings += 1
		endif
	endfor

	let elapsed = strftime('%s') - start
	echon printf("[%2d:%02ds] ", elapsed / 60, elapsed % 60)
	if 0 <# errors
		echon "\u274c Build failed: "
		echohl Error
		echon errors " errors"
		echohl None
		if 0 <# warnings
			echon ", "
			echohl WarningMsg
			echon warnings " warnings"
			echohl None
		endif
	elseif 0 <# warnings
		echon "\U1f64c Build finished: "
		echohl WarningMsg
		echon warnings " warnings"
		echohl None
	else
		echon "\U1f64f Build finished"
		call feedkeys("\<CR>", "nt")
		cclose
	endif
endfunction

function! make#qf() abort
	if !empty(getqflist())
		botright copen
		silent! cfirst
		copen
		call search('error:')
		execute 'normal!' "\<CR>"
		cc
	else
		silent! cclose
	endif
endfunction

function! s:guess_makeprg() abort
	if !empty(&l:makeprg)
		return
	endif

	if filereadable('Makefile')
		setlocal makeprg=make
	elseif filereadable('meson.build')
		setlocal makeprg=meson\ compile\ -C\ build
	elseif filereadable('go.mod')
		compiler go
	elseif filereadable(get(Git(), 'wd', '').'Cargo.toml')
		compiler cargo
	elseif filereadable('package.json')
		setlocal makeprg=npm\ run\ build
	endif
endfunction

function! s:bell() abort
	call writefile(["\x07"], '/dev/tty', 'b')
endfunction
