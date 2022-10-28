" Highlight illegal whitespace. (Red on white.)
if exists('#japan')
	finish
endif

augroup japan
	autocmd!
	autocmd ColorScheme * highlight default WhitespaceError ctermbg=197 ctermfg=231 guibg=#ff005f guifg=#ffffff
	doautocmd ColorScheme vimrc_japan
	autocmd FileType,BufWinEnter,WinNew *
		\ if has_key(w:, 'japan')|
		\   call matchdelete(w:japan)|
		\   unlet w:japan|
		\ endif|
		\ if &buftype ==# '' && !&readonly && &modifiable && &filetype !~# '\v^(|text|markdown|mail)$|git|diff|log' |
		\   let w:japan = matchadd('WhitespaceError', '\v +\t+|\s+%#@!$', 10)|
		\ endif
augroup END

command! Japan keepjumps keeppatterns lockmarks silent %s/\m\s\+$//e
