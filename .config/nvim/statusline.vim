Source git.vim

augroup vimrc_statusline
	autocmd!
	" No extra noise.
	set noshowmode

	" function! s:get_file_icon()
	" 	let b:icon = get(b:, 'icon', matchstr(substitute(system(['ls', '--color=always', '-d1', '--', bufname()]), \"\e[^m]*m\", '', 'g'), '..'))
	" 	return b:icon
	" endfunction

	set tabline=%!Tabline()
	function! s:get_buf_name(bufnr)
		let path = bufname(a:bufnr)
		return !empty(path) ? fnamemodify(path, ':gs?/*$??:t') : '[No Name]'
	endfunction

	function! Tabline()
		let tabs = ''
		let curtabnr = tabpagenr()
		let ntabs = tabpagenr('$')
		for tabnr in range(1, ntabs)
			let bufnrs = tabpagebuflist(tabnr)
			let winnr = tabpagewinnr(tabnr)

			let bufnr = bufnrs[winnr - 1]

			let tab = tabnr.':'.s:get_buf_name(bufnr)

			if getbufvar(bufnr, '&modified')
				let tab .= ' [+]'
			else
				for bufnr in bufnrs
					if getbufvar(bufnr, '&modified')
						let tab .= ' +'
						break
					endif
				endfor
			endif

			let tabs .= '%'.tabnr.'T%#TabLine'.(tabnr == curtabnr ? 'Sel' : '').'# '.tab.' '
		endfor
		return tabs.'%#TabLineFill#%T'
	endfunction

	let g:recent_buffers = []
	function! StatusLineRecentBuffers() abort
		let s = ''
		let altbufnr = bufnr('#')
		for bufnr in g:recent_buffers
			if bufnr != bufnr() && getbufvar(bufnr, '&buflisted') && index(['quickfix', 'prompt'], getbufvar(bufnr, '&buftype')) ==# -1
				let s .= (bufnr ==# altbufnr ? '#' : bufnr).':'.s:get_buf_name(bufnr).' '
				if &columns <= strlen(s)
					break
				endif
			endif
		endfor
		return s
	endfunction

	let g:diff_lnum = '    '
	function! s:StatusLineCursorChanged() abort
		let lnum = line('.')
		let g:diff_lnum = printf('%4s', get(s:, 'prev_lnum', lnum) != lnum ? (lnum > s:prev_lnum ? '+' : '').(lnum - s:prev_lnum) : '')
		let s:prev_lnum = lnum
	endfunction

	function! StatusLineFiletypeIcon() abort
		return get({ 'unix': '', 'dos': '', 'mac': '' }, &fileformat, '')
	endfunction

	autocmd CursorMoved * call s:StatusLineCursorChanged()

		" \ setlocal statusline+=%2p%%\ %4l/%-4L:%-3v
	autocmd WinLeave *
		\ setlocal statusline=%n:%f%h%w%(\ %m%)|
		\ setlocal statusline+=%=|
		\ setlocal statusline+=%2p%%\ %4l/%-4L\ L:%-3v\ C
	autocmd VimEnter,WinEnter,BufWinEnter *
		\ setlocal statusline=%(%#StatusLineModeTerm#%{'t'==mode()?'\ \ T\ ':''}%#StatusLineModeTermEnd#%{'t'==mode()?'\ ':''}%#StatusLine#%)|
		\ setlocal statusline+=%(\ %{DebuggerDebugging()?'🦋🐛🐝🐞🐧🦠':''}\ %)|
		\ setlocal statusline+=%(%(\ %{!&diff&&argc()>#1?(argidx()+1).'\ of\ '.argc():''}\ %)%(\ \ %{GitStatus()}\ %)\ %)|
		\ setlocal statusline+=%n:%f%h%w%{exists('b:gzflag')?'[GZ]':''}%r%(\ %m%)%k|
		\ setlocal statusline+=%9*%<%(\ %{StatusLineRecentBuffers()}%)%#StatusLine#|
		\ setlocal statusline+=%=|
		\ setlocal statusline+=%1*%2*|
		\ setlocal statusline+=%(\ %{&paste?'ρ':''}\ %)|
		\ setlocal statusline+=%(\ %{&spell?&spelllang:''}\ \ %)|
		\ setlocal statusline+=\ %{!&binary?(substitute((!empty(&fenc)?&fenc:&enc).(&bomb?',bom':'').'\ ','\\m^utf-8\ $','','').StatusLineFiletypeIcon()):\"bin\ \\uf471\"}|
		\ setlocal statusline+=%(\ \ %{!&binary?!empty(&ft)?&ft:'no\ ft':''}%)|
		\ setlocal statusline+=\ %3*\ %2p%%\ %4l/%-4L\ %{diff_lnum}\ L:%3v\ C

	autocmd InsertEnter,BufWipeout * let s:index = index(g:recent_buffers, bufnr())|if s:index >= 0|silent! unlet! g:recent_buffers[s:index]|endif
	autocmd InsertEnter * call insert(g:recent_buffers, bufnr())
augroup END
