" NVim bug statusline with \n \e \0 (zero width probably) messes up character
" count. Followed by multi-width character crashes attrs[i] > 0.
augroup vimrc_statusline
	autocmd!
	set noshowmode laststatus=2
	set tabline=%!statusline#tabline()

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
		\ setlocal statusline+=%(%(\ %{!&diff&&argc()>#1?(argidx()+1).'\ of\ '.argc():''}\ %)%(\ \ %{GitBuffer().status}\ %)\ %)|
		\ setlocal statusline+=%n:%f%h%w%{exists('b:gzflag')?'[GZ]':''}%r%(\ %m%)%k|
		\ setlocal statusline+=%9*%<%#StatusLine#|
		\ setlocal statusline+=%<%=|
		\ setlocal statusline+=%1*%2*|
		\ setlocal statusline+=%(\ %{&paste?'ρ':''}\ %)|
		\ setlocal statusline+=%(\ %{&spell?&spelllang:''}\ \ %)|
		\ setlocal statusline+=%(\ %{substitute(&binary?'bin':(!empty(&fenc)?&fenc:&enc).(&bomb?',bom':'').(&fileformat!=#'unix'?','.&fileformat:''),'^utf-8$','','')}\ %)|
		\ setlocal statusline+=%(\ %{!&binary&&!empty(&ft)?&ft:''}\ %)|
		\ setlocal statusline+=%3*\ %l(%{statusline_lnum_change})/%L:%-3v
augroup END
