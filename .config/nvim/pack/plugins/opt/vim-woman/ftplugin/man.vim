for s:bookmark in split('sSYNOPSIS i#include dDESCRIPTION r^RETURN<bar>^EXIT eERRORS xEXAMPLES eSEE', ' ')
	execute "nnoremap <silent><buffer><nowait> g".s:bookmark[0]." :call cursor(1, 1)<bar>call search('\\v".s:bookmark[1:]."', 'W')<bar>normal! zt<CR>"
endfor
nnoremap <buffer> <space> <C-D>
nnoremap <silent><buffer><nowait> ] :<C-U>call search('\v^[A-Z0-9]*\(\d', 'W')<CR>zt
nnoremap <silent><buffer><nowait> [ :<C-U>call search('\v^[A-Z0-9]*\(\d', 'Wb')<CR>zt
nnoremap <buffer> /<space><space> /^ \+
