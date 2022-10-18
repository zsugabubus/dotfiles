function! fizzy#choose(opts) abort
	let altbuf = bufnr()
	keepalt enew
	setlocal nobuflisted bufhidden=wipe noswapfile hidden nonumber norelativenumber filetype=
	execute 'autocmd TermClose <buffer> silent! keepalt ' altbuf 'buffer'
	autocmd TermOpen <buffer> startinsert

	let infile = get(a:opts, 'infile', '')
	let tmpfile = ''
	let outfile = tempname()

	if has_key(a:opts, 'inlines')
		let infile = tempname()
		let tmpfile = infile
		call writefile(a:opts.inlines, infile)
	endif

	if has_key(a:opts, 'incmd')
		let shellcmd = printf('%s | fizzy -0j0 >%s', a:opts.incmd, shellescape(outfile))
	else
		let shellcmd = printf('exec fizzy -j0 <%s >%s', shellescape(infile), shellescape(outfile))
	endif

	let s:job = termopen(shellcmd, {
	\ 'bufnr': bufnr(),
	\ 'tmpfile': tmpfile,
	\ 'outfile': outfile,
	\ 'on_reply': a:opts.on_reply,
	\ 'on_exit': function('s:on_exit')
	\})
endfunction

function! s:on_exit(job, data, error) dict abort
	try
		if a:data ==# 0
			let answer = readfile(self.outfile)[-1:][0]
			" Trim NL/NUL.
			let answer = answer[:-2]
			call call(self.on_reply, [answer])
		endif
	finally
		if self.tmpfile !=# ''
			call delete(self.tmpfile)
		endif
		call delete(self.outfile)
		execute 'doautocmd TermClose' fnameescape(bufname(self.bufnr))
	endtry
endfunction

function! fizzy#Buffer() abort
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
		call add(lines, printf("%3d%3s\t%s\tline %d", buf.bufnr, flags, name, buf.lnum))
	endfor

	call fizzy#choose({
	\ 'inlines': lines,
	\ 'on_reply': {answer-> execute(str2nr(answer).'buffer')}
	\})
endfunction

function! fizzy#Files() abort
	call fizzy#choose({
	\ 'incmd': 'rg --files -0',
	\ 'on_reply': {answer-> execute('edit '.fnameescape(answer))}
	\})
endfunction
