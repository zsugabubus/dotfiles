for s:bookmark in split('sSYNOPSIS i#include dDESCRIPTION r^RETURN<bar>^EXIT eERRORS xEXAMPLES eSEE', ' ')
	execute "nnoremap <silent><buffer><nowait> g".s:bookmark[0]." :call cursor(1, 1)<bar>call search('\\v".s:bookmark[1:]."', 'W')<bar>normal! zt<CR>"
endfor
nnoremap <buffer><nowait> d <C-d>
nnoremap <buffer><nowait> u <C-u>
nnoremap <buffer><nowait> <CR> <C-d>
nnoremap <buffer> /<space><space> /^ \+
