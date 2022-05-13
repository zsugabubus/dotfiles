augroup vimrc_statusline
	autocmd!
	set noshowmode laststatus=2

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
		return ''
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

	autocmd InsertEnter,BufWipeout * let s:index = index(g:recent_buffers, bufnr())|if s:index >= 0|silent! unlet! g:recent_buffers[s:index]|endif
	autocmd InsertEnter * call insert(g:recent_buffers, bufnr())

	" autocmd OptionSet binary,fenc,enc,bomb,fileformat echom 'kecske'

	let g:statusline_lnum_change = ''
	let s:prev_lnum = 0
	autocmd CursorMoved *
		\ let s:lnum = line('.')|
		\ if s:lnum !=# s:prev_lnum|
		\   let g:statusline_lnum_change = printf('%+d', s:lnum - s:prev_lnum)|
		\   let s:prev_lnum = s:lnum|
		\ endif

	autocmd WinLeave,FocusLost *
		\ setlocal statusline=%#StatusLineNC#%n:%f%h%w%(\ %m%)|
		\ setlocal statusline+=%=|
		\ setlocal statusline+=%l/%L:%-3v
	autocmd VimEnter,WinEnter,BufWinEnter,FocusGained *
		\ setlocal statusline=%(%#StatusLineModeTerm#%{'t'==mode()?'\ \ T\ ':''}%#StatusLineModeTermEnd#%{'t'==mode()?'\ ':''}%#StatusLine#%)|
		\ setlocal statusline+=%(\ %{DebuggerDebugging()?'🦋🐛🐝🐞🐧🦠':''}\ %)|
		\ setlocal statusline+=%(%(\ %{!&diff&&argc()>#1?(argidx()+1).'\ of\ '.argc():''}\ %)%(\ \ %{GitBuffer().status}\ %)\ %)|
		\ setlocal statusline+=%n:%f%h%w%{exists('b:gzflag')?'[GZ]':''}%r%(\ %m%)%k|
		\ setlocal statusline+=%9*%<%(\ %{StatusLineRecentBuffers()}%)%#StatusLine#|
		\ setlocal statusline+=%<%=|
		\ setlocal statusline+=%1*%2*|
		\ setlocal statusline+=%(\ %{&paste?'ρ':''}\ %)|
		\ setlocal statusline+=%(\ %{&spell?&spelllang:''}\ \ %)|
		\ setlocal statusline+=%(\ %{substitute(&binary?'bin':(!empty(&fenc)?&fenc:&enc).(&bomb?',bom':'').(&fileformat!=#'unix'?','.&fileformat:''),'^utf-8$','','')}\ %)|
		\ setlocal statusline+=%(\ %{!&binary&&!empty(&ft)?&ft:''}\ %)|
		\ setlocal statusline+=%3*\ %l(%{statusline_lnum_change})/%L:%-3v
augroup END
