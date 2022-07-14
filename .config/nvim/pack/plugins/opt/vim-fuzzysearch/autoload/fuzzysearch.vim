let s:pattern = ''
let s:job = -1

function! s:on_stdout(job, lines, event) abort
	try
		let lines = map(a:lines[:-2], 'str2nr(v:val)')
		let lines = lines[:999]
		let @/ = empty(lines) ? '' : '\v^%('.join(map(lines, {_,lnum-> '%'.(lnum + 1).'l'}), '|').')'
		execute printf('silent! normal! %dGNn', s:origlnum)
		redraw!
	catch
		let @/ = ''
		nohlsearch
		redraw!
	endtry
endfunction

function! s:on_exit(job, exitcode, event) abort
	let s:pattern = ''
	let s:lines = ''
endfunction

function! s:do_search(pattern, final) abort
	if !a:final && !&hlsearch
		return
	endif
	if s:pattern !=# a:pattern
		call jobstop(s:job)

		if empty(s:pattern)
			let s:origlnum = line('.')
			if s:engine ==# 'fzf'
				let s:lines = map(getline(1, '$'), {lnum,line-> lnum."\t".line})
			elseif s:engine ==# 'fizzy'
				let s:lines = getline(1, '$')
			else
				throw 'unknown engine' s:engine
			endif
		endif

		let s:pattern = a:pattern
		if empty(s:pattern)
			return
		endif

		if s:engine ==# 'fzf'
			let cmdline = ['fzf', '--no-sort', "--delimiter=\t", '--nth=2..', '-f', s:pattern]
		elseif s:engine ==# 'fizzy'
			let cmdline = ['fizzy', '-isfq', s:pattern]
		endif

		let s:job = jobstart(cmdline, {
		\  'on_exit': function('s:on_exit'),
		\  'on_stdout': function('s:on_stdout'),
		\  'stdout_buffered': 1
		\})

		call chansend(s:job, s:lines)
		call chanclose(s:job, 'stdin')
	else
		let @/ = ''
		nohlsearch
	endif

	if a:final
		try
			if jobwait([s:job])[0] <# 0
				call jobstop(s:job)
			endif
		catch
			call jobstop(s:job)
		endtry
	endif
endfunction

function! fuzzysearch#search(...) abort
	let s:engine = get(a:000, 0, 'fzf')
	let pattern = input({
	\  'prompt': 'z/',
	\  'highlight': {pattern-> [s:do_search(pattern, 0), []][1]}
	\})
	call s:do_search(pattern, 1)
endfunction
