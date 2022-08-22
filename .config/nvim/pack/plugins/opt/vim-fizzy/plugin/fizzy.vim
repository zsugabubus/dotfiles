command! FizzyBuffers call s:fizzy_buffer()
command! FizzyFiles call s:fizzy_files()

function s:fizzy_buffer() abort
	let lines = []
	let curbuf = bufnr()
	for buf in getbufinfo({
	\ 'buflisted': 1
	\})->sort({x,y-> y.lastused - x.lastused})
		if buf.bufnr ==# curbuf
			continue
		endif
		let name = bufname(buf.bufnr)
		if empty(name)
			let name = '[No Name]'
		endif
		let flags = buf.changed ? '+' : ''
		call add(lines, printf("%3d%3s\t%s\tline %d",
			\ buf.bufnr, flags, name, buf.lnum))
	endfor

	let infile = tempname()
	let outfile = tempname()
	call writefile(lines, infile)

	keepjump enew
	setlocal nobuflisted bufhidden=wipe noswapfile hidden nonumber norelativenumber filetype=
	execute 'autocmd TermClose <buffer> ' curbuf 'buffer'
	let shellcmd = printf('exec fizzy -j0 <%s >%s', shellescape(infile), shellescape(outfile))
	let s:job = termopen(shellcmd, {
	\ 'infile': infile,
	\ 'outfile': outfile,
	\ 'on_exit': function('s:on_fizzy_buffer_exit')
	\})
endfunction

function s:fizzy_files() abort
	let curbuf = bufnr()
	let outfile = tempname()
	keepjump enew
	setlocal nobuflisted bufhidden=wipe noswapfile hidden nonumber norelativenumber filetype=
	execute 'autocmd TermClose <buffer> ' curbuf 'buffer'
	let shellcmd = printf('rg --files -0 | fizzy -0j0 >%s', shellescape(outfile))
	let s:job = termopen(shellcmd, {
	\ 'outfile': outfile,
	\ 'on_exit': function('s:on_fizzy_files_exit')
	\})
endfunction

function s:on_fizzy_files_exit(job, data, error) dict abort
	if a:data ==# 0
		let answer = readfile(self.outfile)[-1:][0]
		" Trim NUL.
		let answer = answer[:-2]
		execute 'edit' fnameescape(answer)
	endif
	call delete(self.outfile)
endfunction

function s:on_fizzy_buffer_exit(job, data, error) dict abort
	call delete(self.infile)
	if a:data ==# 0
		let answer = readfile(self.outfile)[-1:][0]
		let buf = str2nr(answer)
		execute buf 'buffer'
	endif
	call delete(self.outfile)
endfunction
