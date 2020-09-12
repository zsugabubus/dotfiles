" Highlight trailing whitespaces.
command! StripTrailingWhite keepjumps keeppatterns lockmarks silent %s/\m\s\+$//e
augroup vimrc_japan
	autocmd!
	autocmd ColorScheme * highlight ExtraWhitespace ctermbg=197 ctermfg=231 guibg=#ff005f guifg=#ffffff
	autocmd BufReadPost * if !&readonly && &modifiable && index(['', 'text', 'git', 'markdown', 'mail', 'diff'], &filetype) ==# -1 |
		\		call matchadd('ExtraWhitespace', '\v +\t+|\s+%#@!$', 10)|
		\	endif
augroup END
