function! git#blame#open(firstlin, lastlin, range, cmd) abort
	let cmd = a:cmd

	" Default range if not specified.
	if match(cmd, '^-L') == -1
		if a:range == 1
			let cmd += ['-L'.a:firstlin]
		elseif a:range == 2
			let cmd += ['-L'.a:firstlin.','.a:lastlin]
		endif
	endif

	let cmd = ['blame'] + cmd + ['--', expand('%')]
	call call('git#cmd#run', ['git#blame#_stdout'] + cmd, {})
endfunction

function! git#blame#jump(flags) abort
	call search('\v^([^ ]* ).*\n\zs\1@!', 'W'.a:flags)
	let @/ = '\V'.escape(matchstr(getline(line('.')), '\m^[^ ]*'), '\')

	" Setting it to 1 does nothing hence this workaround.
	if !v:hlsearch
		call feedkeys(":set hlsearch|echo\<CR>", 'n')
	endif
endfunction

function! git#blame#_stdout(data) abort dict
	if len(a:data) <= 1
		return
	endif

	let cur_buf = bufnr()
	let view = winsaveview()
	let cur_lnum = line('.')
	setlocal scrollbind

	vertical leftabove new
	setlocal filetype=gitblame bufhidden=wipe buftype=nofile noswapfile undolevels=-1

	execute 'autocmd BufWipeout <buffer> call setbufvar(' cur_buf ', "&scrollbind", 0)'

	for line in a:data
		let lnum = +matchstr(line, '\v \zs\d+\ze\) ')
		let start_lnum = min([lnum, line('$') + 1])
		let blanks = repeat([''], lnum - start_lnum)
		call setline(start_lnum, blanks + [line])
	endfor

	call cursor(cur_lnum, 1)
	call winrestview(view)
	setlocal nomodifiable scrollbind

	GblameDate
endfunction

function! git#blame#width(pat) abort
	let b:git_blame_winwidth = match(getline(nextnonblank(1)), a:pat) + 1
	execute 'vertical resize' b:git_blame_winwidth
	call cursor(0, 1)
endfunction

function! git#blame#do_winresize() abort
	let winnr = winnr()
	for win in range(1, winnr('$'))
		let buf = winbufnr(win)
		let winwidth = getbufvar(buf, 'git_blame_winwidth')
		if winwidth
			execute win 'windo vertical resize' winwidth
		endif
	endfor
endfunction

augroup git_blame
	autocmd!

	" Defer window resizing since nvim crashes if it is done as part of the
	" autocmd handler.
	autocmd VimResized * if mode(1) ==# 'n'|call feedkeys(":call git#blame#do_winresize()|echo\<CR>", 'ni')|endif
augroup END
