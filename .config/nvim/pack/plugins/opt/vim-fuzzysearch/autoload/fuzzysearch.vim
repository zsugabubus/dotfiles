let s:pattern = ''
let s:job = -1

function! s:tdout(job, lines, event) abort
	try
		let lines = map(a:lines[:-2], 'str2nr(v:val)')
		let @/ = empty(lines) ? '' : '\v^%('.join(map(lines, {_,lnum-> '%'.lnum.'l'}), '|').')'
		execute printf('silent! normal! %dGNn', s:origlnum)
		redraw!
	catch
		let @/ = ''
		nohlsearch
		redraw!
	endtry
endfunction

function! s:top(job, exitcode, event) abort
	let s:pattern = ''
	let s:lines = ''
endfunction

function! s:earch(pattern, final) abort
	if !a:final && !&hlsearch
		return
	endif
	if s:pattern !=# a:pattern
		call jobstop(s:job)

		if empty(s:pattern)
			let s:origlnum = line('.')
			let s:lines = map(getline(1, '$'), {idx,line-> (idx + 1)."\t".line})
		endif

		let s:pattern = a:pattern
		if empty(s:pattern)
			return
		endif

		let lines = []

		let s:job = jobstart(['fzf', '--no-sort', "--delimiter=\t", '--nth=2..', '-f', s:pattern], {
		\  'on_exit': function('s:top'),
		\  'stdout_buffered': 1,
		\  'on_stdout': function('s:tdout')
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
	let pat = input({'prompt': 'z/', 'highlight': {pat-> [s:earch(pat, 0), []][1]}})
	call s:earch(pat, 1)
endfunction
