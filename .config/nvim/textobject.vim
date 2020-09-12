" Parameter.

onoremap <silent> i, :<C-U>execute "keeppattern normal! v?\\m[(,]?;/\\S/\<lt>CR>o/\\m[,)]/s-1\<lt>CR>"<CR>
" onoremap <silent> a, :<C-U>execute \"keeppattern normal! v/\\v,\\s*\\zs|\\zs)\<lt>CR>\"<CR>

" Inner line.
xnoremap il <Esc>_vg_
xnoremap al <Esc>0v$h
omap <silent> il :<C-U>normal vil<CR>
omap <silent> al :<C-U>normal val<CR>

" Statement.
onoremap <silent> i; :<C-U>execute "keeppattern normal! 0v/;/$\<lt>CR>"<CR>
onoremap <silent> a; :<C-U>execute "keeppattern normal! 0v/;/;/\\m^\s*/$\<lt>CR>"<CR>

" Backticks.
onoremap <silent> i` :<C-U>execute "keeppattern normal! v?\\v`\\_.{-}%#<bar>%#`?s+1\<lt>CR>o/`/e-1\<lt>CR>"<CR>
onoremap <silent> a` :<C-U>execute "keeppattern normal! v?\\v`\\_.{-}%#<bar>%#`\<lt>CR>o/\\m`\\s*/e\<lt>CR>"<CR>

" Indentation.
vnoremap ii :<C-U>execute "keeppattern normal! 0/\\v\\s\\S\<lt>CR>V/\\v^(\\s+)\\S.*%(\\n<bar>\\1.*)*/e\<lt>CR>"<CR>
omap <silent> ii :<C-U>normal vii<CR>
